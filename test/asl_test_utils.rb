module AslTestUtils
  def setup
    super
    ActiveSambaLdap::Base.establish_connection({}, false)

    @user_class = Class.new(ActiveSambaLdap::User)
    @user_class.ldap_mapping
    @computer_class = Class.new(ActiveSambaLdap::Computer)
    @computer_class.ldap_mapping
    @group_class = Class.new(ActiveSambaLdap::Group)
    @group_class.ldap_mapping

    @user_class.group_class = @group_class
    @computer_class.group_class = @group_class

    @original_ldifs = ""
    @user_index = 0
    @computer_index = 0
    @group_index = 0
    begin
      @original_ldifs = ActiveSambaLdap::Base.dump
      ActiveSambaLdap::Base.destroy_all
      ActiveSambaLdap::Base.populate
    rescue ActiveLDAP::ConnectionError
    end
  end

  def teardown
    ActiveSambaLdap::Base.destroy_all
    ActiveSambaLdap::Base.load(@original_ldifs)
    ActiveSambaLdap::Base.close
    super
  end

  def make_dummy_user(config={})
    @user_index += 1
    name = config[:name] || "test-user#{@user_index}"
    home_directory = config[:home_directory] || "/tmp/#{name}-#{Process.pid}"
    ensure_delete_user(name, home_directory) do
      password = config[:password] || "password"
      uid_number = config[:uid_number] || "100000#{@user_index}"
      default_user_gid = ActiveSambaLdap::DefaultConfig.default_user_gid
      gid_number = config[:gid_number] || default_user_gid
      _wrap_assertion do
        user = @user_class.new(name)
        assert(!user.exists?)
        user.init(uid_number, gid_number)
        user.homeDirectory = home_directory
        user.change_password(password)
        user.change_samba_password(password)
        user.save!
        FileUtils.mkdir(home_directory)
        assert(user.exists?)
        yield(user, password)
      end
    end
  end

  def ensure_delete_user(uid, home=nil)
    yield(uid, home)
  ensure
    FileUtils.rm_rf(home) if home
    user = @user_class.new(uid)
    if user.exists?
      groups = @group_class.find_all(:attribute => "memberUid",
                                     :value => user.uid)
      groups.each do |group|
        @group_class.new(group).remove_member(user)
      end
      user.destroy
    end
  end

  def make_dummy_computer(config={})
    @computer_index += 1
    name = config[:name] || "test-computer#{@computer_index}$"
    home_directory = config[:home_directory] || "/tmp/#{name}-#{Process.pid}"
    ensure_delete_computer(name, home_directory) do |name, home_directory|
      password = config[:password]
      uid_number = config[:uid_number] || "100000#{@computer_index}"
      default_computer_gid = ActiveSambaLdap::DefaultConfig.default_computer_gid
      gid_number = config[:gid_number] || default_computer_gid
      _wrap_assertion do
        computer = @computer_class.new(name)
        assert(!computer.exists?)
        computer.init(uid_number, gid_number)
        if password
          computer.change_password(password)
          computer.change_samba_password(password)
        end
        computer.save!
        FileUtils.mkdir(home_directory)
        assert(computer.exists?)
        yield(computer, password)
      end
    end
  end

  def ensure_delete_computer(uid, home=nil)
    yield(uid.sub(/\$+\z/, '') + "$", home)
  ensure
    FileUtils.rm_rf(home) if home
    computer = @computer_class.new(uid)
    if computer.exists?
      groups = @group_class.find_all(:attribute => "memberUid",
                                     :value => computer.uid)
      groups.each do |group|
        @group_class.new(group).remove_member(computer)
      end
      computer.destroy
    end
  end

  def make_dummy_group(config={})
    @group_index += 1
    name = config[:name] || "test-group#{@group_index}"
    ensure_delete_group(name) do
      gid_number = config[:gid_number] || "200000#{@group_index}"
      group_type = config[:group_type] || "domain"
      _wrap_assertion do
        group = @group_class.new(name)
        assert(!group.exists?)
        group.change_gid_number(gid_number)
        group.change_type(group_type)
        group.save!
        assert(group.exists?)
        yield(group)
      end
    end
  end

  def ensure_delete_group(name)
    yield(name)
  ensure
    group = @group_class.new(name)
    group.destroy if group.exists?
  end

  def ensure_delete_ou(ou)
    yield(ou)
  ensure
    ou_class = Class.new(ActiveSambaLdap::Ou)
    ou_class.ldap_mapping
    ou_obj = ou_class.new(ou)
    ou_obj.destroy if ou_obj.exists?
  end

  def pool
    pool_class = Class.new(ActiveSambaLdap::UnixIdPool)
    pool_class.ldap_mapping
    ActiveSambaLdap::Config.required_variables :samba_domain
    pool_class.new(ActiveSambaLdap::Config.samba_domain)
  end

  def next_uid_number
    pool.uidNumber(true) || @user_class.start_uid
  end

  def next_gid_number
    pool.gidNumber(true) || @group_class.start_gid
  end
end
