require 'asl_test_utils'

class AslUserAddTest < Test::Unit::TestCase
  include AslTestUtils

  def setup
    super
    @command = File.join(@bin_dir, "asl-useradd")
  end

  def test_run_as_normal_user
    assert_equal([false, "need root authority.\n"],
                 run_asl_useradd_as_normal_user("user-name"))
    assert_equal([false, "need root authority.\n"],
                 run_asl_useradd_as_normal_user("computer-name$",
                                                "--computer-account"))
  end

  def test_exist_user
    make_dummy_user do |user, password|
      assert(@user_class.exists?(user.uid))
      assert_equal([false, "user '#{user.uid}' already exists.\n"],
                   run_asl_useradd(user.uid))
      assert(@user_class.exists?(user.uid))
    end
  end

  def test_exist_computer
    make_dummy_computer do |computer, password|
      uid = computer.uid
      assert(@computer_class.exists?(uid))
      assert_equal([false, "computer '#{uid}' already exists.\n"],
                   run_asl_useradd(uid, "--computer-account"))
      assert(@computer_class.exists?(uid))
    end
  end

  def test_add_user
    ensure_delete_user("test-user") do |uid,|
      assert_asl_useradd_successfully(uid)
    end
  end

  def test_add_computer
    ensure_delete_computer("test-computer$") do |uid,|
      assert_asl_useradd_successfully(uid, "--computer-account")
    end

    ensure_delete_computer("test-computer") do |uid,|
      assert_asl_useradd_successfully(uid, "--computer-account")
    end
  end

  def test_ou_user
    ensure_delete_ou("SubOu") do |ou|
      ou_class = Class.new(ActiveSambaLdap::Ou)
      ou_class.ldap_mapping :prefix => @user_class.prefix
      assert(!ou_class.exists?(ou))

      ensure_delete_user("test-user") do |uid,|
        user_class = Class.new(ActiveSambaLdap::User)
        user_class.ldap_mapping :prefix => "ou=#{ou},#{@user_class.prefix}"

        assert(!user_class.exists?(uid))
        assert_equal([true, ""], run_asl_useradd(uid, "--ou", ou))
        assert(user_class.exists?(uid))

        user = user_class.find(uid)
        assert_match(/\Auid=#{uid},ou=#{ou},/, user.dn)
      end

      assert(ou_class.exists?(ou))
    end
  end

  def test_ou_computer
    ensure_delete_ou("SubOu") do |ou|
      ou_class = Class.new(ActiveSambaLdap::Ou)
      ou_class.ldap_mapping :prefix => @computer_class.prefix
      assert(!ou_class.exists?(ou))

      ensure_delete_computer("test-computer$") do |uid,|
        computer_class = Class.new(ActiveSambaLdap::Computer)
        computer_class.ldap_mapping :prefix =>
                                    "ou=#{ou},#{@computer_class.prefix}"

        assert(!computer_class.exists?(uid))
        assert_equal([true, ""], run_asl_useradd(uid, "--computer-account",
                                                 "--ou", ou))
        assert(computer_class.exists?(uid))

        computer = computer_class.find(uid)
        assert_match(/\Auid=#{Regexp.escape(uid)},ou=#{ou},/, computer.dn)
      end

      assert(ou_class.exists?(ou))
    end
  end

  def test_uid_number
    ensure_delete_user("test-user") do |uid,|
      uid_number = Integer(next_uid_number) + 10
      assert_asl_useradd_successfully(uid, "--uid", uid_number)
      user = @user_class.find(uid)
      assert_equal(uid_number, user.uidNumber.to_i)
    end

    ensure_delete_computer("test-computer$") do |uid,|
      uid_number = Integer(next_uid_number) + 10
      assert_asl_useradd_successfully(uid, "--computer-account",
                                      "--uid", uid_number)
      computer = @computer_class.find(uid)
      assert_equal(uid_number, computer.uidNumber.to_i)
    end
  end

  def test_gid_number
    make_dummy_group("test-group") do |group|
      gid_number = group.gidNumber

      ensure_delete_user("test-user") do |uid,|
        assert_asl_useradd_successfully(uid, "--gid", gid_number)
        user = @user_class.find(uid)
        assert_equal(gid_number, user.gidNumber)
      end

      ensure_delete_computer("test-computer") do |uid,|
        assert_asl_useradd_successfully(uid, "--computer-account",
                                        "--gid", gid_number)
        computer = @computer_class.find(uid)
        assert_equal(gid_number, computer.gidNumber)
      end
    end
  end

  def test_groups
    make_dummy_group do |group1|
      make_dummy_group do |group2|
        make_dummy_group do |group3|
          gid_numbers = [group1.gidNumber,
                         group2.gidNumber,
                         group3.gidNumber]

          ensure_delete_user("test-user") do |uid,|
            args = ["--groups", gid_numbers.join(",")]
            assert_asl_useradd_successfully(uid, *args)

            user = @user_class.find(uid)
            primary_group = @group_class.find(:first,
                                              :attribute => "gidNumber",
                                              :value => user.gidNumber)
            groups = @group_class.find(:all,
                                       :attribute => "memberUid",
                                       :value => uid)
            assert_equal([primary_group.cn,
                          group1.cn,
                          group2.cn,
                          group3.cn].sort,
                         groups.collect {|g| g.cn}.sort)
          end

          ensure_delete_computer("test-computer$") do |uid,|
            args = ["--computer-account", "--groups", gid_numbers.join(",")]
            assert_asl_useradd_successfully(uid, *args)

            computer = @computer_class.find(uid)
            primary_group = @group_class.find(:first,
                                              :attribute => "gidNumber",
                                              :value => computer.gidNumber)
            groups = @group_class.find(:all,
                                       :attribute => "memberUid",
                                       :value => uid)
            assert_equal([primary_group.cn,
                          group1.cn,
                          group2.cn,
                          group3.cn].sort,
                         groups.collect {|g| g.cn}.sort)
          end
        end
      end
    end
  end

  def test_create_group_user
    ensure_delete_group("test-user") do |gid,|
      ensure_delete_user("test-user") do |uid,|
        assert_equal(gid, uid)
        assert(!@group_class.exists?(gid))
        assert_asl_useradd_successfully(uid, "--create-group")
        assert(@group_class.exists?(gid))

        user = @user_class.find(uid)
        group = @group_class.find(gid)
        assert_equal(group.gidNumber, user.gidNumber)
      end
    end
  end

  def test_create_group_computer
    ensure_delete_group("test-computer") do |gid,|
      ensure_delete_computer("test-computer$") do |uid,|
        assert_equal("#{gid}$", uid)
        assert(!@group_class.exists?(gid))
        assert_asl_useradd_successfully(uid, "--create-group",
                                        "--computer-account")
        assert(@group_class.exists?(gid))

        computer = @computer_class.find(uid)
        group = @group_class.find(gid)
        assert_equal(group.gidNumber, computer.gidNumber)
      end
    end
  end

  def test_comment_user
    ensure_delete_user("test-user") do |uid,|
      gecos = "gecos for the user #{uid}"
      assert_asl_useradd_successfully(uid, "--comment", gecos)
      user = @user_class.find(uid)
      assert_equal(gecos, user.gecos)
    end
  end

  def test_comment_computer
    ensure_delete_computer("test-computer$") do |uid,|
      gecos = "gecos for the computer #{uid}"
      assert_asl_useradd_successfully(uid, "--computer-account",
                                      "--comment", gecos)
      computer = @computer_class.find(uid)
      assert_equal(gecos, computer.gecos)
    end
  end

  def test_shell_user
    ensure_delete_user("test-user") do |uid,|
      shell = "/bin/zsh"
      assert_asl_useradd_successfully(uid, "--shell", shell)
      user = @user_class.find(uid)
      assert_equal(shell, user.loginShell)
    end
  end

  def test_shell_computer
    ensure_delete_computer("test-computer") do |uid,|
      shell = "/bin/zsh"
      assert_asl_useradd_successfully(uid, "--computer-account",
                                      "--shell", shell)
      computer = @computer_class.find(uid)
      assert_equal(shell, computer.loginShell)
    end
  end

  def test_canonical_name_user
    ensure_delete_user("test-user") do |uid,|
      cn = "John Kennedy"
      assert_asl_useradd_successfully(uid, "--canonical-name", cn)
      user = @user_class.find(uid)
      assert_equal(uid, user.givenName)
      assert_equal(uid, user.surname)
      assert_equal(cn, user.cn)
    end
  end

  def test_canonical_name_computer
    ensure_delete_computer("test-computer$") do |uid,|
      cn = "A computer"
      assert_asl_useradd_successfully(uid, "--computer-account",
                                      "--canonical-name", cn)
      computer = @computer_class.find(uid)
      assert_equal(uid, computer.givenName)
      assert_equal(uid, computer.surname)
      assert_equal(cn, computer.cn)
    end
  end

  def test_given_name_user
    ensure_delete_user("test-user") do |uid,|
      given_name = "John"
      assert_asl_useradd_successfully(uid, "--given-name", given_name)
      user = @user_class.find(uid)
      assert_equal(given_name, user.givenName)
      assert_equal(uid, user.cn)
    end
  end

  def test_given_name_computer
    ensure_delete_computer("test-computer$") do |uid,|
      given_name = "John"
      assert_asl_useradd_successfully(uid, "--computer-account",
                                      "--given-name", given_name)
      computer = @computer_class.find(uid)
      assert_equal(given_name, computer.givenName)
      assert_equal(uid, computer.cn)
    end
  end

  def test_surname_user
    ensure_delete_user("test-user") do |uid,|
      surname = "Kennedy"
      assert_asl_useradd_successfully(uid, "--surname", surname)
      user = @user_class.find(uid)
      assert_equal(surname, user.surname)
      assert_equal(uid, user.cn)
    end
  end

  def test_surname_computer
    ensure_delete_computer("test-computer$") do |uid,|
      surname = "Kennedy"
      assert_asl_useradd_successfully(uid, "--computer-account",
                                      "--surname", surname)
      computer = @computer_class.find(uid)
      assert_equal(surname, computer.surname)
      assert_equal(uid, computer.cn)
    end
  end

  def test_given_name_and_surname_user
    ensure_delete_user("test-user") do |uid,|
      given_name = "John"
      surname = "Kennedy"
      assert_asl_useradd_successfully(uid,
                                      "--given-name", given_name,
                                      "--surname", surname)
      user = @user_class.find(uid)
      assert_equal(given_name, user.givenName)
      assert_equal(surname, user.surname)
      assert_equal("#{given_name} #{surname}", user.cn)
    end
  end

  def test_given_name_and_surname_computer
    ensure_delete_computer("test-computer$") do |uid,|
      given_name = "John"
      surname = "Kennedy"
      assert_asl_useradd_successfully(uid,
                                      "--computer-account",
                                      "--given-name", given_name,
                                      "--surname", surname)
      computer = @computer_class.find(uid)
      assert_equal(given_name, computer.givenName)
      assert_equal(surname, computer.surname)
      assert_equal("#{given_name} #{surname}", computer.cn)
    end
  end

  def test_home_directory_user
    ensure_delete_user("test-user") do |uid,|
      home_directory = "/tmp/#{File.basename(__FILE__)}.#{Process.pid}"
      begin
        assert_asl_useradd_successfully(uid,
                                        "--home-directory", home_directory,
                                        "--setup-home-directory")
        assert(File.exist?(home_directory))
      ensure
        FileUtils.rm_rf(home_directory)
      end
    end
  end

  def test_home_directory_computer
    ensure_delete_computer("test-computer$") do |uid,|
      home_directory = "/tmp/#{File.basename(__FILE__)}.#{Process.pid}"
      begin
        assert_asl_useradd_successfully(uid,
                                        "--computer-account",
                                        "--home-directory", home_directory,
                                        "--setup-home-directory")
        assert(File.exist?(home_directory))
      ensure
        FileUtils.rm_rf(home_directory)
      end
    end
  end

  def test_skeleton_directory
    home_directory = File.join(Dir.tmpdir,
                               "#{File.basename(__FILE__)}.#{Process.pid}")
    skeleton_directory = "#{home_directory}.skel"
    begin
      normal_file = "hello"
      dot_file = ".hello"
      deep_file = File.join("dir", "hello")
      FileUtils.touch([normal_file, dot_file, deep_file].collect do |f|
                        target = File.join(skeleton_directory, f)
                        FileUtils.mkdir_p(File.dirname(target))
                        target
                      end)

      ensure_delete_user("test-user") do |uid,|
        assert_asl_useradd_successfully(uid,
                                        "--home-directory", home_directory,
                                        "--skeleton-directory",
                                        skeleton_directory,
                                        "--setup-home-directory")
        assert(File.exist?(home_directory))
        assert(File.exist?(File.join(home_directory, normal_file)))
        assert(File.exist?(File.join(home_directory, dot_file)))
        assert(File.exist?(File.join(home_directory, deep_file)))
      end

      ensure_delete_computer("test-computer$") do |uid,|
        assert_asl_useradd_successfully(uid,
                                        "--computer-account",
                                        "--home-directory", home_directory,
                                        "--skeleton-directory",
                                        skeleton_directory,
                                        "--setup-home-directory")
        assert(File.exist?(home_directory))
        assert(File.exist?(File.join(home_directory, normal_file)))
        assert(File.exist?(File.join(home_directory, dot_file)))
        assert(File.exist?(File.join(home_directory, deep_file)))
      end
    ensure
      FileUtils.rm_rf([home_directory, skeleton_directory])
    end
  end

  def test_expire_date_user
    ensure_delete_user("test-user") do |uid,|
      expire_date = Time.now + 60 * 24
      assert_asl_useradd_successfully(uid, "--expire-date", expire_date.iso8601)
      user = @user_class.find(uid)
      assert_equal(expire_date.to_i.to_s, user.sambaKickoffTime)
    end
  end

  def test_expire_date_computer
    ensure_delete_computer("test-computer$") do |uid,|
      expire_date = Time.now + 60 * 24
      assert_asl_useradd_successfully(uid, "--computer-account",
                                      "--expire-date", expire_date.iso8601)
      computer = @computer_class.find(uid)
      assert_nil(computer.sambaKickoffTime)
    end
  end

  def test_can_change_password_user
    ensure_delete_user("test-user") do |uid,|
      assert_asl_useradd_successfully(uid, "--can-change-password")
      user = @user_class.find(uid)
      assert(user.can_change_password?)
    end
  end

  def test_can_change_password_computer
    ensure_delete_computer("test-computer$") do |uid,|
      ensure_delete_computer("test-computer2$") do |uid2,|
        assert_asl_useradd_successfully(uid, "--computer-account")
        assert_asl_useradd_successfully(uid2, "--computer-account",
                                        "--can-change-password")
        computer = @computer_class.find(uid)
        computer2 = @computer_class.find(uid2)
        assert_equal(computer.can_change_password?,
                     computer2.can_change_password?)
      end
    end
  end

  def test_no_can_change_password_user
    ensure_delete_user("test-user") do |uid,|
      assert_asl_useradd_successfully(uid, "--no-can-change-password")
      user = @user_class.find(uid)
      assert(!user.can_change_password?)
    end
  end

  def test_no_can_change_password_computer
    ensure_delete_computer("test-computer$") do |uid,|
      ensure_delete_computer("test-computer2$") do |uid2,|
        assert_asl_useradd_successfully(uid, "--computer-account")
        assert_asl_useradd_successfully(uid2, "--computer-account",
                                        "--no-can-change-password")
        computer = @computer_class.find(uid)
        computer2 = @computer_class.find(uid2)
        assert_equal(computer.can_change_password?,
                     computer2.can_change_password?)
      end
    end
  end

  def test_must_change_password_user
    ensure_delete_user("test-user") do |uid,|
      assert_asl_useradd_successfully(uid, "--must-change-password")
      user = @user_class.find(uid)
      assert(user.must_change_password?)
    end
  end

  def test_must_change_password_computer
    ensure_delete_computer("test-computer$") do |uid,|
      ensure_delete_computer("test-computer2$") do |uid2,|
        assert_asl_useradd_successfully(uid, "--computer-account")
        assert_asl_useradd_successfully(uid2, "--computer-account",
                                        "--must-change-password")
        computer = @computer_class.find(uid)
        computer2 = @computer_class.find(uid2)
        assert_equal(computer.must_change_password?,
                     computer2.must_change_password?)
      end
    end
  end

  def test_no_must_change_password_user
    ensure_delete_user("test-user") do |uid,|
      assert_asl_useradd_successfully(uid, "--no-must-change-password")
      user = @user_class.find(uid)
      assert(!user.must_change_password?)
    end
  end

  def test_no_must_change_password_computer
    ensure_delete_computer("test-computer$") do |uid,|
      ensure_delete_computer("test-computer2$") do |uid2,|
        assert_asl_useradd_successfully(uid, "--computer-account")
        assert_asl_useradd_successfully(uid2, "--computer-account",
                                        "--no-must-change-password")
        computer = @computer_class.find(uid)
        computer2 = @computer_class.find(uid2)
        assert_equal(computer.must_change_password?,
                     computer2.must_change_password?)
      end
    end
  end

  def test_samba_home_path_user
    ensure_delete_user("test-user") do |uid,|
      home_path = "\\\\ANYWHERE\\here\\%U"
      assert_asl_useradd_successfully(uid, "--samba-home-path", home_path)
      user = @user_class.find(uid)
      assert_equal(home_path.gsub(/%U/, uid), user.sambaHomePath)
    end
  end

  def test_samba_home_path_computer
    ensure_delete_computer("test-computer$") do |uid,|
      home_path = "\\\\ANYWHERE\\here\\%U"
      assert_asl_useradd_successfully(uid, "--computer-account",
                                      "--samba-home-path", home_path)
      computer = @computer_class.find(uid)
      assert_nil(computer.sambaHomePath)
    end
  end

  def test_samba_home_drive_user
    ensure_delete_user("test-user") do |uid,|
      home_drive = "X:"
      assert_asl_useradd_successfully(uid, "--samba-home-drive", home_drive)
      user = @user_class.find(uid)
      assert_equal(home_drive, user.sambaHomeDrive)
    end
  end

  def test_samba_home_drive_computer
    ensure_delete_computer("test-computer$") do |uid,|
      home_drive = "X:"
      assert_asl_useradd_successfully(uid, "--computer-account",
                                      "--samba-home-drive", home_drive)
      computer = @computer_class.find(uid)
      assert_nil(computer.sambaHomeDrive)
    end
  end

  def test_samba_home_drive_abbrev_user
    ensure_delete_user("test-user") do |uid,|
      home_drive = "X"
      assert_asl_useradd_successfully(uid, "--samba-home-drive", home_drive)
      user = @user_class.find(uid)
      assert_equal("#{home_drive}:", user.sambaHomeDrive)
    end
  end

  def test_samba_home_drive_abbrev_computer
    ensure_delete_computer("test-computer$") do |uid,|
      home_drive = "X"
      assert_asl_useradd_successfully(uid, "--computer-account",
                                      "--samba-home-drive", home_drive)
      computer = @computer_class.find(uid)
      assert_nil(computer.sambaHomeDrive)
    end
  end

  def test_samba_logon_script_user
    ensure_delete_user("test-user") do |uid,|
      script = "%U-logon.bat"
      assert_asl_useradd_successfully(uid, "--samba-logon-script", script)
      user = @user_class.find(uid)
      assert_equal(script.gsub(/%U/, uid), user.sambaLogonScript)
    end
  end

  def test_samba_logon_script_computer
    ensure_delete_computer("test-computer$") do |uid,|
      script = "%U-logon.bat"
      assert_asl_useradd_successfully(uid, "--computer-account",
                                      "--samba-logon-script", script)
      computer = @computer_class.find(uid)
      assert_nil(computer.sambaLogonScript)
    end
  end

  def test_samba_profile_path_user
    ensure_delete_user("test-user") do |uid,|
      profile = "\\\\ANYWHERE\\profiles\\profile-%U"
      assert_asl_useradd_successfully(uid, "--samba-profile-path", profile)
      user = @user_class.find(uid)
      assert_equal(profile.gsub(/%U/, uid), user.sambaProfilePath)
    end
  end

  def test_samba_profile_path_computer
    ensure_delete_computer("test-computer$") do |uid,|
      profile = "\\\\ANYWHERE\\profiles\\profile-%U"
      assert_asl_useradd_successfully(uid, "--computer-account",
                                      "--samba-profile-path", profile)
      computer = @computer_class.find(uid)
      assert_nil(computer.sambaProfilePath)
    end
  end

  def test_samba_account_flags_user
    ensure_delete_user("test-user") do |uid,|
      flags = "[UX]"
      assert_asl_useradd_successfully(uid, "--samba-account-flags", flags)
      user = @user_class.find(uid)
      assert_equal(flags, user.sambaAcctFlags)
    end
  end

  def test_samba_account_flags_computer
    ensure_delete_computer("test-computer$") do |uid,|
      flags = "[WX]"
      assert_asl_useradd_successfully(uid, "--computer-account",
                                      "--samba-account-flags", flags)
      computer = @computer_class.find(uid)
      assert_equal(flags, computer.sambaAcctFlags)
    end
  end

  private
  def run_asl_useradd(*other_args, &block)
    other_args = prepare_args(other_args)
    run_command(*other_args, &block)
  end

  def run_asl_useradd_as_normal_user(*other_args, &block)
    other_args = prepare_args(other_args)
    run_command_as_normal_user(*other_args, &block)
  end

  def prepare_args(args)
    args = args.dup
    if args.grep(/\A--(no-)?setup-home-directory\z/).empty?
      args << "--no-setup-home-directory"
    end
    if args.grep(/\A--(no-)?create-group\z/).empty?
      args << "--no-create-group"
    end
    args
  end

  def assert_asl_useradd_successfully(name, *args)
    _wrap_assertion do
      if args.grep(/\A--computer-account\z/).empty?
        member_class = @user_class
      else
        name = name.sub(/\$*\z/, '') + "$"
        member_class = @computer_class
      end
      assert(!member_class.exists?(name))
      args << name
      assert_equal([true, ""], run_asl_useradd(*args))
      assert(member_class.exists?(name))
    end
  end

  def assert_asl_useradd_failed(name, message, *args)
    _wrap_assertion do
      if args.grep(/\A--computer-account\z/).empty?
        member_class = @user_class
      else
        name = name.sub(/\$*\z/, '') + "$"
        member_class = @computer_class
      end
      assert(!member_class.exists?(name))
      args << name
      assert_equal([false, message], run_asl_useradd(*args))
      assert(!member_class.exists?(name))
    end
  end
end
