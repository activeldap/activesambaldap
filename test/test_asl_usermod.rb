require 'asl-test-utils'

class AslUserModTest < Test::Unit::TestCase
  include AslTestUtils

  def setup
    super
    @command = File.join(@bin_dir, "asl-usermod")
  end

  def test_not_exist_user
    assert_equal([false, "", _("user doesn't exist: %s") % 'not-exist' + "\n"],
                 run_command("not-exist"))
  end

  def test_gecos
    make_dummy_user do |user, password|
      old_gecos = user.gecos
      new_gecos = "New gecos"
      assert_not_equal(old_gecos, new_gecos)
      args = ["--gecos", new_gecos]
      assert_asl_usermod_successfully(user.uid, password, *args)
      new_user = @user_class.find(user.uid)
      assert_equal(new_gecos, new_user.gecos)
      assert_equal(new_gecos, new_user.description)
      assert_equal(new_gecos, new_user.display_name)
    end
  end

  def test_home_directory
    make_dummy_user do |user, password|
      old_home_directory = user.home_directory
      new_home_directory = "#{old_home_directory}.new"
      args = ["--home-directory", new_home_directory]
      assert_asl_usermod_successfully(user.uid, password, *args)
      new_user = @user_class.find(user.uid)
      assert_equal(new_home_directory, new_user.home_directory)
    end
  end

  def test_move_home_directory
    make_dummy_user do |user, password|
      begin
        old_home_directory = user.home_directory
        new_home_directory = "#{old_home_directory}.new"
        assert(!File.exist?(new_home_directory))
        args = ["--home-directory", new_home_directory, "--move-home-directory"]
        assert_asl_usermod_successfully(user.uid, password, *args)
        new_user = @user_class.find(user.uid)
        assert_equal(new_home_directory, new_user.home_directory)
        assert(File.exist?(new_home_directory))
      ensure
        FileUtils.rm_rf(new_home_directory)
      end
    end
  end

  def test_rename
    make_dummy_user do |user, password|
      old_uid = user.uid
      new_uid = "#{old_uid}-new"

      ensure_delete_user(new_uid) do
        assert(!@user_class.exists?(new_uid))

        args = ["--rename", new_uid]
        assert_asl_usermod_successfully(user.uid, password, *args)

        assert(!@user_class.exists?(old_uid))
        assert(@user_class.exists?(new_uid))

        new_user = @user_class.find(new_uid)
        assert_equal(new_uid, new_user.uid)
        assert_equal(new_uid, new_user.cn)
      end
    end
  end

  def test_uid_number
    make_dummy_user do |user, password|
      old_uid_number = user.uid_number
      old_samba_sid = user.samba_sid
      new_uid_number = old_uid_number.succ

      old_rid = (2 * Integer(old_uid_number) + 1000).to_s
      new_rid = (2 * Integer(new_uid_number) + 1000).to_s
      new_samba_sid = old_samba_sid.sub(/#{Regexp.escape(old_rid)}$/, new_rid)

      args = ["--uid", new_uid_number]
      assert_asl_usermod_successfully(user.uid, password, *args)

      new_user = @user_class.find(user.uid)
      assert_equal(new_uid_number, new_user.uid_number)
      assert_equal(new_samba_sid, new_user.samba_sid)
    end
  end

  def test_uid_number_non_unique
    make_dummy_user do |user, password|
      old_uid_number = user.uid_number
      new_uid_number = old_uid_number.succ
      make_dummy_user(:name => "#{user.uid}2",
                      :uid_number => new_uid_number) do |user2, password2|
        old_samba_sid = user.samba_sid
        old_rid = (2 * Integer(old_uid_number) + 1000).to_s
        new_rid = (2 * Integer(new_uid_number) + 1000).to_s
        new_samba_sid = old_samba_sid.sub(/#{Regexp.escape(old_rid)}$/, new_rid)

        message = _("uid number already exists: %s") % new_uid_number + "\n"
        args = ["--uid", new_uid_number]
        assert_asl_usermod_failed(user.uid, password, message, *args)

        new_user = @user_class.find(user.uid)
        assert_equal(old_uid_number, new_user.uid_number)
        assert_equal(old_samba_sid, new_user.samba_sid)
      end
    end
  end

  def test_uid_number_allow_non_unique
    make_dummy_user do |user, password|
      old_uid_number = user.uid_number
      new_uid_number = old_uid_number.succ
      make_dummy_user(:name => "#{user.uid}2",
                      :uid_number => new_uid_number) do |user2, password2|
        old_samba_sid = user.samba_sid
        old_rid = (2 * Integer(old_uid_number) + 1000).to_s
        new_rid = (2 * Integer(new_uid_number) + 1000).to_s
        new_samba_sid = old_samba_sid.sub(/#{Regexp.escape(old_rid)}$/, new_rid)

        args = ["--uid", new_uid_number, "--allow-non-unique-uid"]
        assert_asl_usermod_successfully(user.uid, password, *args)

        new_user = @user_class.find(user.uid)
        assert_equal(new_uid_number, new_user.uid_number)
        assert_equal(new_samba_sid, new_user.samba_sid)
      end
    end
  end

  def test_gid_number
    make_dummy_group do |group|
      make_dummy_user(:gid_number => group.gid_number) do |user, password|
        make_dummy_group do |new_group|
          args = ["--gid", new_group.gid_number]
          assert_asl_usermod_successfully(user.uid, password, *args)

          new_user = @user_class.find(user.uid)
          assert_equal(new_group.gid_number, new_user.gid_number)
          assert_equal(new_group.samba_sid,
                       new_user.samba_primary_group_sid)
        end
      end
    end
  end

  def test_gid_number_not_exist
    make_dummy_user do |user, password|
      make_dummy_group do |group|
        old_gid_number = user.gid_number
        new_gid_number = group.gid_number
        old_samba_primary_group_sid = user.samba_primary_group_sid

        group.destroy
        args = ["--gid", new_gid_number]
        message = _("gid number doesn't exist: %s") % new_gid_number + "\n"
        assert_asl_usermod_failed(user.uid, password, message, *args)

        new_user = @user_class.find(user.uid)
        assert_equal(old_gid_number, new_user.gid_number)
        assert_equal(old_samba_primary_group_sid,
                     new_user.samba_primary_group_sid)
      end
    end
  end

  def test_groups
    make_dummy_group do |group1|
      make_dummy_group do |group2|
        make_dummy_group do |group3|
          new_gid_number1 = group1.gid_number
          new_gid_number2 = group2.gid_number
          new_gid_number3 = group3.gid_number
          new_gid_numbers = [new_gid_number1, new_gid_number2, new_gid_number3]

          make_dummy_user do |user, password|
            old_gid_number = user.gid_number
            old_groups = @group_class.find(:all,
                                           :attribute => "memberUid",
                                           :value => user.uid)

            args = ["--groups", new_gid_numbers.join(",")]
            assert_asl_usermod_successfully(user.uid, password, *args)


            new_user = @user_class.find(user.uid)
            new_groups = @group_class.find(:all,
                                           :attribute => "memberUid",
                                           :value => new_user.uid)
            assert_equal([group1.cn,
                          group2.cn,
                          group3.cn].sort,
                         (new_groups.collect {|g| g.cn} -
                          old_groups.collect {|g| g.cn}).sort)
          end
        end
      end
    end
  end

  def test_groups_no_merge
    make_dummy_group do |group1|
      make_dummy_group do |group2|
        make_dummy_group do |group3|
          new_gid_number1 = group1.gid_number
          new_gid_number2 = group2.gid_number
          new_gid_number3 = group3.gid_number
          new_gid_numbers = [new_gid_number1, new_gid_number2, new_gid_number3]
          make_dummy_user do |user, password|
            old_gid_number = user.gid_number
            old_groups = @group_class.find(:all,
                                           :attribute => "memberUid",
                                           :value => user.uid)

            args = ["--groups", new_gid_numbers[0]]
            assert_asl_usermod_successfully(user.uid, password, *args)

            new_user = @user_class.find(user.uid)
            new_groups = @group_class.find(:all,
                                           :attribute => "memberUid",
                                           :value => new_user.uid)
            assert_equal([group1.cn].sort,
                         (new_groups.collect {|g| g.cn} -
                          old_groups.collect {|g| g.cn}).sort)


            args = ["--groups", new_gid_numbers[1..-1].join(","),
                    "--no-merge-groups"]
            assert_asl_usermod_successfully(user.uid, password, *args)

            new_user = @user_class.find(user.uid)
            new_groups = @group_class.find(:all,
                                           :attribute => "memberUid",
                                           :value => new_user.uid)
            assert_equal([group2.cn, group3.cn].sort,
                         new_groups.collect {|g| g.cn}.sort)
          end
        end
      end
    end
  end

  def test_groups_not_exist
    make_dummy_group do |group1|
      make_dummy_group do |group2|
        new_gid_number1 = group1.gid_number
        new_gid_number2 = group2.gid_number
        new_gid_numbers = [new_gid_number1, new_gid_number2]

        group1.destroy
        group2.destroy

        make_dummy_user do |user, password|
          old_gid_number = user.gid_number

          assert(!@group_class.exists?(group1.cn))

          old_groups = @group_class.find(:all,
                                         :attribute => "memberUid",
                                         :value => user.uid)

          args = ["--groups", new_gid_numbers.join(",")]
          message = _("gid number doesn't exist: %s") % new_gid_numbers[0] + "\n"
          assert_asl_usermod_failed(user.uid, password, message, *args)

          new_user = @user_class.find(user.uid)
          new_groups = @group_class.find(:all,
                                         :attribute => "memberUid",
                                         :value => new_user.uid)
          assert_equal(old_groups.collect {|g| g.cn}.sort,
                       new_groups.collect {|g| g.cn}.sort)
        end
      end
    end
  end

  def test_shell
    make_dummy_user do |user, password|
      old_shell = user.login_shell
      new_shell = "/bin/zsh"

      assert_not_equal(old_shell, new_shell)

      args = ["--shell", new_shell]
      assert_asl_usermod_successfully(user.uid, password, *args)

      new_user = @user_class.find(user.uid)
      assert_equal(new_shell, new_user.login_shell)
    end
  end

  def test_common_name
    make_dummy_user do |user, password|
      old_cn = user.cn
      new_cn = "new-#{new_cn}"

      args = ["--common-name", new_cn]
      assert_asl_usermod_successfully(user.uid, password, *args)

      new_user = @user_class.find(user.uid)
      assert_equal(new_cn, new_user.cn)
    end
  end

  def test_surname
    make_dummy_user do |user, password|
      old_sn = user.sn
      new_sn = "new-#{old_sn}"

      args = ["--surname", new_sn]
      assert_asl_usermod_successfully(user.uid, password, *args)

      new_user = @user_class.find(user.uid)
      assert_equal(new_sn, new_user.sn)
    end
  end

  def test_given_name
    make_dummy_user do |user, password|
      old_given_name = user.given_name
      new_given_name = "new-#{old_given_name}"

      args = ["--given-name", new_given_name]
      assert_asl_usermod_successfully(user.uid, password, *args)

      new_user = @user_class.find(user.uid)
      assert_equal(new_given_name, new_user.given_name)
    end
  end

  def test_expire_date
    make_dummy_user do |user, password|
      old_expire_date = user.samba_kickoff_time
      new_expire_date = Time.now + 60 * 24

      unless old_expire_date.nil?
        assert_not_equal(Time.at(old_expire_date.to_i), new_expire_date)
      end

      args = ["--expire-date", new_expire_date.iso8601]
      assert_asl_usermod_successfully(user.uid, password, *args)

      new_user = @user_class.find(user.uid)
      assert_equal(new_expire_date.to_i.to_s, new_user.samba_kickoff_time)
    end
  end

  def test_can_change_password
    make_dummy_user do |user, password|
      unless user.can_change_password?
        args = ["--can-change-password"]
        assert_asl_usermod_successfully(user.uid, password, *args)
        new_user = @user_class.find(user.uid)
        assert(new_user.can_change_password?)
      end

      args = ["--no-can-change-password"]
      assert_asl_usermod_successfully(user.uid, password, *args)
      new_user = @user_class.find(user.uid)
      assert(!new_user.can_change_password?)

      args = ["--can-change-password"]
      assert_asl_usermod_successfully(user.uid, password, *args)
      new_user = @user_class.find(user.uid)
      assert(new_user.can_change_password?)
    end
  end

  def test_must_change_password
    make_dummy_user do |user, password|
      unless user.must_change_password?
        args = ["--must-change-password"]
        assert_asl_usermod_successfully(user.uid, password, *args)
        new_user = @user_class.find(user.uid)
        assert(new_user.must_change_password?)
      end

      args = ["--no-must-change-password"]
      assert_asl_usermod_successfully(user.uid, password, *args)
      new_user = @user_class.find(user.uid)
      assert(!new_user.must_change_password?)

      args = ["--must-change-password"]
      assert_asl_usermod_successfully(user.uid, password, *args)
      new_user = @user_class.find(user.uid)
      assert(new_user.must_change_password?)
    end
  end

  def test_samba_home_path
    make_dummy_user do |user, password|
      old_samba_home_path = user.samba_home_path
      new_samba_home_path = "//PDC/NEW-HOME"

      assert_not_equal(old_samba_home_path, new_samba_home_path)

      args = ["--samba-home-path", new_samba_home_path]
      assert_asl_usermod_successfully(user.uid, password, *args)

      new_user = @user_class.find(user.uid)
      assert_equal(new_samba_home_path, new_user.samba_home_path)
    end
  end

  def test_samba_home_drive
    make_dummy_user do |user, password|
      old_samba_home_drive = user.samba_home_drive
      new_samba_home_drive = "X:"

      assert_not_equal(old_samba_home_drive, new_samba_home_drive)

      args = ["--samba-home-drive", new_samba_home_drive]
      assert_asl_usermod_successfully(user.uid, password, *args)

      new_user = @user_class.find(user.uid)
      assert_equal(new_samba_home_drive, new_user.samba_home_drive)
    end
  end

  def test_samba_logon_script
    make_dummy_user do |user, password|
      old_samba_logon_script = user.samba_logon_script
      new_samba_logon_script = "\\\\PDC\\scripts\\logon-new.bat"

      assert_not_equal(old_samba_logon_script, new_samba_logon_script)

      args = ["--samba-logon-script", new_samba_logon_script]
      assert_asl_usermod_successfully(user.uid, password, *args)

      new_user = @user_class.find(user.uid)
      assert_equal(new_samba_logon_script, new_user.samba_logon_script)
    end
  end

  def test_samba_profile_path
    make_dummy_user do |user, password|
      old_samba_profile_path = user.samba_profile_path
      new_samba_profile_path = "\\\\PDC\\profiles\\new-profile"

      assert_not_equal(old_samba_profile_path, new_samba_profile_path)

      args = ["--samba-profile-path", new_samba_profile_path]
      assert_asl_usermod_successfully(user.uid, password, *args)

      new_user = @user_class.find(user.uid)
      assert_equal(new_samba_profile_path, new_user.samba_profile_path)
    end
  end

  def test_samba_account_flags
    make_dummy_user do |user, password|
      old_samba_account_flags = user.samba_acct_flags
      new_samba_account_flags = "[UX]"

      assert_not_equal(old_samba_account_flags, new_samba_account_flags)

      args = ["--samba-account-flags", new_samba_account_flags]
      assert_asl_usermod_successfully(user.uid, password, *args)

      new_user = @user_class.find(user.uid)
      assert_equal(new_samba_account_flags, new_user.samba_acct_flags)
    end
  end

  def test_enable
    make_dummy_user do |user, password|
      unless user.enabled?
        args = ["--enable-user"]
        assert_asl_usermod_successfully(user.uid, password, *args)
        new_user = @user_class.find(user.uid)
        assert(new_user.enabled?)
        assert(!new_user.disabled?)
      end

      args = ["--no-enable-user"]
      assert_asl_usermod_successfully(user.uid, password, *args)
      new_user = @user_class.find(user.uid)
      assert(!new_user.enabled?)
      assert(new_user.disabled?)

      args = ["--enable-user"]
      assert_asl_usermod_successfully(user.uid, password, *args)
      new_user = @user_class.find(user.uid)
      assert(new_user.enabled?)
      assert(!new_user.disabled?)
    end
  end

  def test_disable
    make_dummy_user do |user, password|
      unless user.disabled?
        args = ["--disable-user"]
        assert_asl_usermod_successfully(user.uid, password, *args)
        new_user = @user_class.find(user.uid)
        assert(!new_user.enabled?)
        assert(new_user.disabled?)
      end

      args = ["--no-disable-user"]
      assert_asl_usermod_successfully(user.uid, password, *args)
      new_user = @user_class.find(user.uid)
      assert(new_user.enabled?)
      assert(!new_user.disabled?)

      args = ["--disable-user"]
      assert_asl_usermod_successfully(user.uid, password, *args)
      new_user = @user_class.find(user.uid)
      assert(!new_user.enabled?)
      assert(new_user.disabled?)
    end
  end

  private
  def assert_asl_usermod_successfully(name, password, *args)
    args << name
    assert_equal([true, _("Enter your password: ") + "\n", ""],
                 run_command_as_normal_user(*args) do |input, output|
                   output.puts password
                   output.puts password
                 end)
  end

  def assert_asl_usermod_failed(name, password, message, *args)
    args << name
    assert_equal([false, _("Enter your password: ") + "\n", message],
                 run_command_as_normal_user(*args) do |input, output|
                   output.puts password
                   output.puts password
                 end)
  end
end
