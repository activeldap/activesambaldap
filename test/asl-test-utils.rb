require 'test/unit'

require 'rbconfig'
require 'fileutils'
require 'tmpdir'

require File.join(File.dirname(__FILE__), "command")

require 'active_samba_ldap'

module AslTestUtils
  def self.included(base)
    base.class_eval do
      include ActiveSambaLdap::GetTextSupport
      include Configuration
      include Connection
      include Populate
      include TemporaryEntry
      include CommandSupport
    end
  end

  module Configuration
    def setup
      super
      @test_dir = File.expand_path(File.dirname(__FILE__))
      @top_dir = File.expand_path(File.join(@test_dir, ".."))
      @parent_dir = File.expand_path(File.join(@top_dir, ".."))
      @config_file = File.join(@test_dir, "config.yaml")
      ActiveSambaLdap::Base.configurations = read_config
    end

    def teardown
      super
    end

    def reference_configuration
      ActiveSambaLdap::Base.configurations["reference"]
    end

    def update_configuration
      ActiveSambaLdap::Base.configurations["update"]
    end

    def read_config
      unless File.exist?(@config_file)
        raise "config file for testing doesn't exist: #{@config_file}"
      end
      ActiveSambaLdap::Configuration.read(@config_file)
    end
  end

  module Connection
    def setup
      super
      ActiveSambaLdap::Base.setup_connection(update_configuration)
    end

    def teardown
      super
      ActiveSambaLdap::Base.clear_active_connections!
    end
  end

  module Populate
    def setup
      super
      @dumped_data = ""
      begin
        @dumped_data = ActiveSambaLdap::Base.dump(:scope => :sub)
      rescue ActiveLdap::ConnectionError
      end
      ActiveSambaLdap::Base.purge
      ActiveSambaLdap::Base.populate
    end

    def teardown
      super
      ActiveSambaLdap::Base.setup_connection(update_configuration)
      ActiveSambaLdap::Base.purge
      ActiveSambaLdap::Base.load(@dumped_data)
    end
  end

  module TemporaryEntry
    def setup
      super
      @user_class = Class.new(ActiveSambaLdap::User)
      @user_class.ldap_mapping
      @computer_class = Class.new(ActiveSambaLdap::Computer)
      @computer_class.ldap_mapping
      @group_class = Class.new(ActiveSambaLdap::Group)
      @group_class.ldap_mapping

      @user_class.set_associated_class(:primary_group, @group_class)
      @computer_class.set_associated_class(:primary_group, @group_class)
      @user_class.set_associated_class(:groups, @group_class)
      @computer_class.set_associated_class(:groups, @group_class)

      @group_class.set_associated_class(:users, @user_class)
      @group_class.set_associated_class(:computers, @computer_class)
      @group_class.set_associated_class(:primary_users, @user_class)
      @group_class.set_associated_class(:primary_computers, @computer_class)

      @user_index = 0
      @computer_index = 0
      @group_index = 0
    end

    def make_dummy_user(config={})
      @user_index += 1
      name = config[:name] || "test-user#{@user_index}"
      home_directory = config[:home_directory] || "/tmp/#{name}-#{Process.pid}"
      ensure_delete_user(name, home_directory) do
        password = config[:password] || "password"
        uid_number = config[:uid_number] || (1000000 + @user_index)
        default_user_gid = @user_class.configuration[:default_user_gid]
        gid_number = config[:gid_number] || default_user_gid
        _wrap_assertion do
          assert(!@user_class.exists?(name))
          options = {
            :uid => name,
            :uid_number => uid_number,
            :group => @group_class.find_by_gid_number(gid_number),
            :home_directory => home_directory,
            :password => password,
          }
          user = @user_class.create(options)
          assert_equal([], user.errors.to_a)
          user.save!
          FileUtils.mkdir(home_directory)
          assert(@user_class.exists?(name))
          yield(user, password)
        end
      end
    end

    def ensure_delete_user(uid, home=nil)
      yield(uid, home)
    ensure
      if @user_class.exists?(uid)
        @user_class.find(uid).destroy(:remove_from_group => true,
                                      :remove_home_directory => true)
      end
      FileUtils.rm_rf(home) if home
    end

    def make_dummy_computer(config={})
      @computer_index += 1
      name = config[:name] || "test-computer#{@computer_index}$"
      home_directory = config[:home_directory] || "/tmp/#{name}-#{Process.pid}"
      ensure_delete_computer(name, home_directory) do |name, home_directory|
        password = config[:password]
        uid_number = config[:uid_number] || (1000000 + @computer_index)
        default_computer_gid =
          @computer_class.configuration[:default_computer_gid]
        gid_number = config[:gid_number] || default_computer_gid
        _wrap_assertion do
          assert(!@computer_class.exists?(name))
          options = {
            :uid => name,
            :uid_number => uid_number,
            :group => @group_class.find_by_gid_number(gid_number),
            :password => password,
          }
          computer = @computer_class.create(options)
          assert_equal([], computer.errors.to_a)
          FileUtils.mkdir(home_directory)
          assert(@computer_class.exists?(name))
          yield(computer, password)
        end
      end
    end

    def ensure_delete_computer(uid, home=nil)
      yield(uid.sub(/\$+\z/, '') + "$", home)
    ensure
      if @computer_class.exists?(uid)
        @computer_class.find(uid).destroy(:remove_from_group => true,
                                          :remove_home_directory => true)
      end
      FileUtils.rm_rf(home) if home
    end

    def make_dummy_group(config={})
      @group_index += 1
      name = config[:name] || "test-group#{@group_index}"
      ensure_delete_group(name) do
        gid_number = config[:gid_number] || (2000000 + @group_index)
        group_type = config[:group_type] || "domain"
        _wrap_assertion do
          assert(!@group_class.exists?(name))
          options = {
            :cn => name,
            :gid_number => gid_number,
            :group_type => group_type,
          }
          group = @group_class.create(options)
          assert_equal([], group.errors.to_a)
          assert(@group_class.exists?(name))
          yield(group)
        end
      end
    end

    def ensure_delete_group(name)
      yield(name)
    ensure
      if @group_class.exists?(name)
        @group_class.find(name).destroy(:remove_members => false)
      end
    end

    def ensure_delete_ou(ou)
      yield(ou)
    ensure
      ou_class = Class.new(ActiveSambaLdap::Ou)
      ou_class.ldap_mapping
      ou_class.destroy(ou) if ou_class.exists?(ou)
    end

    def pool
      pool_class = Class.new(ActiveSambaLdap::UnixIdPool)
      pool_class.ldap_mapping
      pool_class.required_configuration_variables :samba_domain
      pool_class.new(pool_class.configuration[:samba_domain])
    end

    def next_uid_number
      pool.uid_number || @user_class.configuration[:start_uid]
    end

    def next_gid_number
      pool.gid_number || @group_class.configuration[:start_gid]
    end
  end

  module CommandSupport
    def setup
      super
      @fakeroot = "fakeroot"
      @ruby = File.join(::Config::CONFIG["bindir"],
                        ::Config::CONFIG["RUBY_INSTALL_NAME"])
      @bin_dir = File.join(@top_dir, "bin")
      @lib_dir = File.join(@top_dir, "lib")
      @ruby_args = [
                    "-I", @lib_dir,
                    "-I", File.join(@parent_dir, "activeldap", "lib"),
#                     "-I", File.join(@parent_dir, "ldap", "lib"),
#                     "-I", File.join(@parent_dir, "ldap"),
                 ]
    end

    def run_command_as_normal_user(*args, &block)
      run_ruby(*[@command, "--config", @config_file, *args], &block)
    end

    def run_command_with_fakeroot(*args, &block)
      run_ruby_with_fakeroot(*[@command, "--config", @config_file, *args],
                             &block)
    end
    alias_method :run_command, :run_command_with_fakeroot

    def run_ruby(*ruby_args, &block)
      args = [@ruby, *@ruby_args]
      args.concat(ruby_args)
      Command.run(*args, &block)
    end

    def run_ruby_with_fakeroot(*ruby_args, &block)
      args = [@fakeroot, @ruby, *@ruby_args]
      args.concat(ruby_args)
      Command.run(*args, &block)
    end
  end
end
