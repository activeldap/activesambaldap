require 'test/unit'
require 'command_support'
require 'asl_test_utils'
require 'fileutils'
require 'time'

require 'active_samba_ldap'

class AslUserModTest < Test::Unit::TestCase
  include CommandSupport
  include AslTestUtils

  def setup
    super
    @asl_usermod = File.join(@bin_dir, "asl-usermod")
  end

  def test_not_exist_user
    assert_equal([false, "user 'not-exist' doesn't exist.\n"],
                 run_asl_usermod("not-exist"))
  end

  def test_gecos
    make_dummy_user do |user, password|
      old_gecos = user.gecos(true)
      new_gecos = "New gecos"
      assert_not_equal(old_gecos, new_gecos)
      args = ["--gecos", new_gecos]
      assert_asl_usermod_successfully(user.uid, password, *args)
      new_user = @user_class.new(user.uid)
      assert_equal(new_gecos, new_user.gecos(true))
      assert_equal(new_gecos, new_user.description(true))
      assert_equal(new_gecos, new_user.displayName(true))
    end
  end

  def test_home_directory
    make_dummy_user do |user, password|
      old_home_directory = user.homeDirectory(true)
      new_home_directory = "#{old_home_directory}.new"
      args = ["--home-directory", new_home_directory]
      assert_asl_usermod_successfully(user.uid, password, *args)
      new_user = @user_class.new(user.uid)
      assert_equal(new_home_directory, new_user.homeDirectory(true))
    end
  end

  def test_move_home_directory
    make_dummy_user do |user, password|
      begin
        old_home_directory = user.homeDirectory(true)
        new_home_directory = "#{old_home_directory}.new"
        assert(!File.exist?(new_home_directory))
        args = ["--home-directory", new_home_directory, "--move-home-directory"]
        assert_asl_usermod_successfully(user.uid, password, *args)
        new_user = @user_class.new(user.uid)
        assert_equal(new_home_directory, new_user.homeDirectory(true))
        assert(File.exist?(new_home_directory))
      ensure
        FileUtils.rm_rf(new_home_directory)
      end
    end
  end

  def test_rename
    make_dummy_user do |user, password|
      begin
        old_uid = user.uid(true)
        new_uid = "#{old_uid}-new"

        new_user = @user_class.new(new_uid)
        assert(!new_user.exists?)

        args = ["--rename", new_uid]
        assert_asl_usermod_successfully(user.uid, password, *args)

        old_user = @user_class.new(old_uid)
        assert(!old_user.exists?)
        new_user = @user_class.new(new_uid)
        assert(new_user.exists?)

        assert_equal(new_uid, new_user.uid(true))
        assert_equal(new_uid, new_user.cn(true))
      ensure
        new_user = @user_class.new(new_uid)
        begin
          new_user.destroy
        rescue ActiveLDAP::DeleteError
        end
      end
    end
  end

  def test_uid_number
    make_dummy_user do |user, password|
      old_uid_number = user.uidNumber(true)
      old_samba_sid = user.sambaSID(true)
      new_uid_number = old_uid_number.succ

      old_rid = (2 * Integer(old_uid_number) + 1000).to_s
      new_rid = (2 * Integer(new_uid_number) + 1000).to_s
      new_samba_sid = old_samba_sid.sub(/#{Regexp.escape(old_rid)}$/, new_rid)

      args = ["--uid", new_uid_number]
      assert_asl_usermod_successfully(user.uid, password, *args)

      new_user = @user_class.new(user.uid)
      assert_equal(new_uid_number, new_user.uidNumber(true))
      assert_equal(new_samba_sid, new_user.sambaSID(true))
    end
  end

  def test_uid_number_non_unique
    make_dummy_user do |user, password|
      old_uid_number = user.uidNumber(true)
      new_uid_number = old_uid_number.succ
      make_dummy_user(:name => "#{user.uid}2",
                      :uid_number => new_uid_number) do |user2, password2|
        old_samba_sid = user.sambaSID(true)
        old_rid = (2 * Integer(old_uid_number) + 1000).to_s
        new_rid = (2 * Integer(new_uid_number) + 1000).to_s
        new_samba_sid = old_samba_sid.sub(/#{Regexp.escape(old_rid)}$/, new_rid)

        message = "uid number '#{new_uid_number}' already exists\n"
        args = ["--uid", new_uid_number]
        assert_asl_usermod_failed(user.uid, password, message, *args)

        new_user = @user_class.new(user.uid)
        assert_equal(old_uid_number, new_user.uidNumber(true))
        assert_equal(old_samba_sid, new_user.sambaSID(true))
      end
    end
  end

  def test_uid_number_allow_non_unique
    make_dummy_user do |user, password|
      old_uid_number = user.uidNumber(true)
      new_uid_number = old_uid_number.succ
      make_dummy_user(:name => "#{user.uid}2",
                      :uid_number => new_uid_number) do |user2, password2|
        old_samba_sid = user.sambaSID(true)
        old_rid = (2 * Integer(old_uid_number) + 1000).to_s
        new_rid = (2 * Integer(new_uid_number) + 1000).to_s
        new_samba_sid = old_samba_sid.sub(/#{Regexp.escape(old_rid)}$/, new_rid)

        args = ["--uid", new_uid_number, "--allow-non-unique-uid"]
        assert_asl_usermod_successfully(user.uid, password, *args)

        new_user = @user_class.new(user.uid)
        assert_equal(new_uid_number, new_user.uidNumber(true))
        assert_equal(new_samba_sid, new_user.sambaSID(true))
      end
    end
  end

  def test_gid_number
    make_dummy_group do |group|
      make_dummy_user(:gid_number => group.gidNumber(true)) do |user, password|
        make_dummy_group do |new_group|
          args = ["--gid", new_group.gidNumber(true)]
          assert_asl_usermod_successfully(user.uid, password, *args)

          new_user = @user_class.new(user.uid)
          assert_equal(new_group.gidNumber(true), new_user.gidNumber(true))
          assert_equal(new_group.sambaSID(true),
                       new_user.sambaPrimaryGroupSID(true))
        end
      end
    end
  end

  def test_gid_number_not_exist
    make_dummy_user do |user, password|
      make_dummy_group do |group|
        old_gid_number = user.gidNumber(true)
        new_gid_number = group.gidNumber(true)
        old_samba_primary_group_sid = user.sambaPrimaryGroupSID(true)

        group.destroy
        args = ["--gid", new_gid_number]
        message = "gid number '#{new_gid_number}' doesn't exist\n"
        assert_asl_usermod_failed(user.uid, password, message, *args)

        new_user = @user_class.new(user.uid)
        assert_equal(old_gid_number, new_user.gidNumber(true))
        assert_equal(old_samba_primary_group_sid,
                     new_user.sambaPrimaryGroupSID(true))
      end
    end
  end

  def test_groups
    make_dummy_group do |group1|
      make_dummy_group do |group2|
        make_dummy_group do |group3|
          new_gid_number1 = group1.gidNumber(true)
          new_gid_number2 = group2.gidNumber(true)
          new_gid_number3 = group3.gidNumber(true)
          new_gid_numbers = [new_gid_number1, new_gid_number2, new_gid_number3]

          make_dummy_user do |user, password|
            old_gid_number = user.gidNumber(true)
            old_groups = @group_class.find_all(:attribute => "memberUid",
                                               :value => user.uid)

            args = ["--groups", new_gid_numbers.join(",")]
            assert_asl_usermod_successfully(user.uid, password, *args)


            new_user = @user_class.new(user.uid)
            new_groups = @group_class.find_all(:attribute => "memberUid",
                                               :value => new_user.uid)
            assert_equal([group1.cn(true),
                          group2.cn(true),
                          group3.cn(true)].sort,
                         (new_groups - old_groups).sort)
          end
        end
      end
    end
  end

  def test_groups_no_merge
    make_dummy_group do |group1|
      make_dummy_group do |group2|
        make_dummy_group do |group3|
          new_gid_number1 = group1.gidNumber(true)
          new_gid_number2 = group2.gidNumber(true)
          new_gid_number3 = group3.gidNumber(true)
          new_gid_numbers = [new_gid_number1, new_gid_number2, new_gid_number3]
          make_dummy_user do |user, password|
            old_gid_number = user.gidNumber(true)
            old_groups = @group_class.find_all(:attribute => "memberUid",
                                               :value => user.uid)

            args = ["--groups", new_gid_numbers[0]]
            assert_asl_usermod_successfully(user.uid, password, *args)

            new_user = @user_class.new(user.uid)
            new_groups = @group_class.find_all(:attribute => "memberUid",
                                               :value => new_user.uid)
            assert_equal([group1.cn(true)].sort,
                         (new_groups - old_groups).sort)


            args = ["--groups", new_gid_numbers[1..-1].join(","),
                    "--no-merge-groups"]
            assert_asl_usermod_successfully(user.uid, password, *args)

            new_user = @user_class.new(user.uid)
            new_groups = @group_class.find_all(:attribute => "memberUid",
                                               :value => new_user.uid)
            assert_equal([group2.cn(true), group3.cn(true)].sort,
                         new_groups.sort)
          end
        end
      end
    end
  end

  def test_groups_not_exist
    make_dummy_group do |group1|
      make_dummy_group do |group2|
        new_gid_number1 = group1.gidNumber(true)
        new_gid_number2 = group2.gidNumber(true)
        new_gid_numbers = [new_gid_number1, new_gid_number2]

        group1.destroy
        group2.destroy

        make_dummy_user do |user, password|
          old_gid_number = user.gidNumber(true)

          assert(!group1.exists?)

          old_groups = @group_class.find_all(:attribute => "memberUid",
                                             :value => user.uid)

          args = ["--groups", new_gid_numbers.join(",")]
          message = "gid number '#{new_gid_numbers[0]}' doesn't exist\n"
          assert_asl_usermod_failed(user.uid, password, message, *args)

          new_user = @user_class.new(user.uid)
          new_groups = @group_class.find_all(:attribute => "memberUid",
                                             :value => new_user.uid)
          assert_equal(old_groups.sort, new_groups.sort)
        end
      end
    end
  end

  def test_shell
    make_dummy_user do |user, password|
      old_shell = user.loginShell(true)
      new_shell = "/bin/zsh"

      assert_not_equal(old_shell, new_shell)

      args = ["--shell", new_shell]
      assert_asl_usermod_successfully(user.uid, password, *args)

      new_user = @user_class.new(user.uid)
      assert_equal(new_shell, new_user.loginShell(true))
    end
  end

  def test_canonical_name
    make_dummy_user do |user, password|
      old_cn = user.cn(true)
      new_cn = "new-#{new_cn}"

      args = ["--canonical-name", new_cn]
      assert_asl_usermod_successfully(user.uid, password, *args)

      new_user = @user_class.new(user.uid)
      assert_equal(new_cn, new_user.cn(true))
    end
  end

  def test_surname
    make_dummy_user do |user, password|
      old_sn = user.sn(true)
      new_sn = "new-#{old_sn}"

      args = ["--surname", new_sn]
      assert_asl_usermod_successfully(user.uid, password, *args)

      new_user = @user_class.new(user.uid)
      assert_equal(new_sn, new_user.sn(true))
    end
  end

  def test_given_name
    make_dummy_user do |user, password|
      old_given_name = user.givenName(true)
      new_given_name = "new-#{old_given_name}"

      args = ["--given-name", new_given_name]
      assert_asl_usermod_successfully(user.uid, password, *args)

      new_user = @user_class.new(user.uid)
      assert_equal(new_given_name, new_user.givenName(true))
    end
  end

  def test_expire_date
    make_dummy_user do |user, password|
      old_expire_date = user.sambaKickoffTime(true)
      new_expire_date = Time.now + 60 * 24

      unless old_expire_date.nil?
        assert_not_equal(Time.at(old_expire_date.to_i), new_expire_date)
      end

      args = ["--expire-date", new_expire_date.iso8601]
      assert_asl_usermod_successfully(user.uid, password, *args)

      new_user = @user_class.new(user.uid)
      assert_equal(new_expire_date.to_i.to_s, new_user.sambaKickoffTime(true))
    end
  end

  def test_can_change_password
    make_dummy_user do |user, password|
      unless user.can_change_password?
        args = ["--can-change-password"]
        assert_asl_usermod_successfully(user.uid, password, *args)
        new_user = @user_class.new(user.uid)
        assert(new_user.can_change_password?)
      end

      args = ["--no-can-change-password"]
      assert_asl_usermod_successfully(user.uid, password, *args)
      new_user = @user_class.new(user.uid)
      assert(!new_user.can_change_password?)

      args = ["--can-change-password"]
      assert_asl_usermod_successfully(user.uid, password, *args)
      new_user = @user_class.new(user.uid)
      assert(new_user.can_change_password?)
    end
  end

  def test_must_change_password
    make_dummy_user do |user, password|
      unless user.must_change_password?
        args = ["--must-change-password"]
        assert_asl_usermod_successfully(user.uid, password, *args)
        new_user = @user_class.new(user.uid)
        assert(new_user.must_change_password?)
      end

      args = ["--no-must-change-password"]
      assert_asl_usermod_successfully(user.uid, password, *args)
      new_user = @user_class.new(user.uid)
      assert(!new_user.must_change_password?)

      args = ["--must-change-password"]
      assert_asl_usermod_successfully(user.uid, password, *args)
      new_user = @user_class.new(user.uid)
      assert(new_user.must_change_password?)
    end
  end

  def test_samba_home_path
    make_dummy_user do |user, password|
      old_samba_home_path = user.sambaHomePath(true)
      new_samba_home_path = "//PDC/NEW-HOME"

      assert_not_equal(old_samba_home_path, new_samba_home_path)

      args = ["--samba-home-path", new_samba_home_path]
      assert_asl_usermod_successfully(user.uid, password, *args)

      new_user = @user_class.new(user.uid)
      assert_equal(new_samba_home_path, new_user.sambaHomePath(true))
    end
  end

  def test_samba_home_drive
    make_dummy_user do |user, password|
      old_samba_home_drive = user.sambaHomeDrive(true)
      new_samba_home_drive = "X:"

      assert_not_equal(old_samba_home_drive, new_samba_home_drive)

      args = ["--samba-home-drive", new_samba_home_drive]
      assert_asl_usermod_successfully(user.uid, password, *args)

      new_user = @user_class.new(user.uid)
      assert_equal(new_samba_home_drive, new_user.sambaHomeDrive(true))
    end
  end

  def test_samba_logon_script
    make_dummy_user do |user, password|
      old_samba_logon_script = user.sambaLogonScript(true)
      new_samba_logon_script = "\\\\PDC\\scripts\\logon-new.bat"

      assert_not_equal(old_samba_logon_script, new_samba_logon_script)

      args = ["--samba-logon-script", new_samba_logon_script]
      assert_asl_usermod_successfully(user.uid, password, *args)

      new_user = @user_class.new(user.uid)
      assert_equal(new_samba_logon_script, new_user.sambaLogonScript(true))
    end
  end

  def test_samba_profile_path
    make_dummy_user do |user, password|
      old_samba_profile_path = user.sambaProfilePath(true)
      new_samba_profile_path = "\\\\PDC\\profiles\\new-profile"

      assert_not_equal(old_samba_profile_path, new_samba_profile_path)

      args = ["--samba-profile-path", new_samba_profile_path]
      assert_asl_usermod_successfully(user.uid, password, *args)

      new_user = @user_class.new(user.uid)
      assert_equal(new_samba_profile_path, new_user.sambaProfilePath(true))
    end
  end

  def test_samba_account_flags
    make_dummy_user do |user, password|
      old_samba_account_flags = user.sambaAcctFlags(true)
      new_samba_account_flags = "[UX]"

      assert_not_equal(old_samba_account_flags, new_samba_account_flags)

      args = ["--samba-account-flags", new_samba_account_flags]
      assert_asl_usermod_successfully(user.uid, password, *args)

      new_user = @user_class.new(user.uid)
      assert_equal(new_samba_account_flags, new_user.sambaAcctFlags(true))
    end
  end

  def test_enable
    make_dummy_user do |user, password|
      unless user.enabled?
        args = ["--enable-user"]
        assert_asl_usermod_successfully(user.uid, password, *args)
        new_user = @user_class.new(user.uid)
        assert(new_user.enabled?)
        assert(!new_user.disabled?)
      end

      args = ["--no-enable-user"]
      assert_asl_usermod_successfully(user.uid, password, *args)
      new_user = @user_class.new(user.uid)
      assert(!new_user.enabled?)
      assert(new_user.disabled?)

      args = ["--enable-user"]
      assert_asl_usermod_successfully(user.uid, password, *args)
      new_user = @user_class.new(user.uid)
      assert(new_user.enabled?)
      assert(!new_user.disabled?)
    end
  end

  def test_disable
    make_dummy_user do |user, password|
      unless user.disabled?
        args = ["--disable-user"]
        assert_asl_usermod_successfully(user.uid, password, *args)
        new_user = @user_class.new(user.uid)
        assert(!new_user.enabled?)
        assert(new_user.disabled?)
      end

      args = ["--no-disable-user"]
      assert_asl_usermod_successfully(user.uid, password, *args)
      new_user = @user_class.new(user.uid)
      assert(new_user.enabled?)
      assert(!new_user.disabled?)

      args = ["--disable-user"]
      assert_asl_usermod_successfully(user.uid, password, *args)
      new_user = @user_class.new(user.uid)
      assert(!new_user.enabled?)
      assert(new_user.disabled?)
    end
  end

  private
  def run_asl_usermod(*other_args, &block)
    run_ruby(*[@asl_usermod, *other_args], &block)
  end

  def assert_asl_usermod_successfully(name, password, *args)
    args << name
    assert_equal([true, "Enter your password: \n"],
                 run_asl_usermod(*args) do |input, output|
                   output.puts password
                   output.puts password
                 end)
  end

  def assert_asl_usermod_failed(name, password, message, *args)
    args << name
    assert_equal([false, "Enter your password: \n#{message}"],
                 run_asl_usermod(*args) do |input, output|
                   output.puts password
                   output.puts password
                 end)
  end
end
