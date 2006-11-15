require 'time'
require 'fileutils'
require 'English'

module ActiveSambaLdap
  module Account
    def self.included(base)
      super
      base.extend(ClassMethods)
    end

    NAME_RE = /\A(?!\d)[\w @_\-\.]+\z/

    module ClassMethods
      def ldap_mapping(options={})
        options = default_options.merge(options)
        super(extract_ldap_mapping_options(options))
        belongs_to :primary_group, primary_group_options(options)
        belongs_to :groups, groups_options(options)
      end

      def valid_name?(name)
        NAME_RE =~ name ? true : false
      end

      def find_by_uid_number(number)
        options = {:objects => true}
        attribute = "uidNumber"
        value = Integer(number)
        find(:first, :filter => "(#{attribute}=#{value})")
      end

      def start_uid
        Integer(configuration[:start_uid])
      end

      def find_available_uid_number(pool)
        uid_number = (pool.uid_number || start_uid).to_s

        100.times do |i|
          if find(:first, :attribute => "uidNumber", :value => uid_number).nil?
            return uid_number
          end
          uid_number = uid_number.succ
        end

        nil
      end

      private
      def default_options
        {
          :dn_attribute => "uid",
          :ldap_scope => :sub,
          :primary_group_class => default_group_class,
          :primary_group_foreign_key => "gidNumber",
          :primary_group_primary_key => "gidNumber",
          :groups_class => default_group_class,
          :groups_many => "memberUid",
          :prefix => default_prefix,
          :classes => default_classes,
        }
      end

      def default_group_class
        "Group"
      end

      def default_classes
        ["top", "inetOrgPerson", "posixAccount"]
      end

      def primary_group_options(options)
        {
          :class => options[:primary_group_class],
          :foreign_key => options[:primary_group_foreign_key],
          :primary_key => options[:primary_group_primary_key],
        }
      end

      def groups_options(options)
        {
          :class => options[:groups_class],
          :many => options[:groups_many],
        }
      end
    end

    def fill_default_values(options={})
      self.cn = uid
      self.sn = uid
      self.gecos = substituted_value(:user_gecos) {uid}
      self.home_directory = substituted_value(:user_home)
      self.login_shell = substituted_value(:user_login_shell)

      self.user_password = "{crypt}x"

      uid_number = options[:uid_number]
      self.change_uid_number(uid_number) if uid_number

      group = options[:group]
      self.primary_group = group if group

      self
    end

    def destroy(options={})
      if options[:removed_from_group]
        groups.each do |group|
          remove_from_group(group)
        end
      end
      dir = home_directory
      need_remove_home_directory =
        options[:remove_home_directory] && !new_entry?
      super()
      if need_remove_home_directory and File.directory?(dir)
        if options[:remove_home_directory_interactive]
          system("rm", "-r", "-i", dir)
        else
          FileUtils.rm_r(dir)
        end
      end
      new_entry?
    end

    def change_uid_number(uid, allow_non_unique=false)
      check_unique_uid_number(uid) unless allow_non_unique
      self.uid_number = Integer(uid).to_s
    end

    def change_password(password)
      hash_type = self.class.configuration[:password_hash_type]
      hashed_password = ActiveLdap::UserPassword.__send__(hash_type, password)
      self.user_password = hashed_password
    end

    private
    def check_unique_uid_number(uid_number)
      ActiveSambaLdap::Base.restart_nscd do
        if self.class.find_by_uid_number(uid_number)
          raise UidNumberAlreadyExists.new(uid_number)
        end
      end
    end

    def substitute_template(template)
      template.gsub(/%U/, uid)
    end

    def substituted_value(key)
      config = self.class.configuration
      if block_given?
        value = config[key.to_sym]
        if value
          substitute_template(value)
        else
          yield
        end
      else
        substitute_template(config[key.to_sym])
      end
    end
  end
end
