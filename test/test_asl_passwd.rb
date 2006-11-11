require 'asl_test_utils'

class AslPasswdTest < Test::Unit::TestCase
  include AslTestUtils

  def setup
    super
    @command = File.join(@bin_dir, "asl-passwd")
  end

  def test_unknown_user
    assert_equal([false, "user 'unknown' doesn't exist.\n"],
                 run_command("unknown"))
  end

  def test_change_password
    make_dummy_user do |user, password|
      new_password = "new#{password}"

      assert_samba_password(user, password)

      assert_change_password_successfully(user.uid,
                                          password, new_password)

      user.reload
      assert_samba_password(user, new_password)

      assert_change_password_with_wrong_current_password(user.uid,
                                                         password)

      assert_change_password_successfully(user.uid,
                                          new_password, password)
      user.reload
      assert_samba_password(user, password)
    end
  end

  def test_change_password_only_unix
    make_dummy_user do |user, password|
      new_password = "new#{password}"
      args = ["--no-samba-password"]

      assert_samba_password(user, password)

      assert_change_password_successfully(user.uid,
                                          password, new_password,
                                          *args)
      user.reload
      assert_samba_password(user, password)

      assert_change_password_with_wrong_current_password(user.uid,
                                                         password, *args)

      assert_change_password_successfully(user.uid,
                                          new_password, password, *args)
      user.reload
      assert_samba_password(user, password)
    end
  end

  def test_change_password_only_samba
    make_dummy_user do |user, password|
      new_password = "new#{password}"
      args = ["--no-unix-password"]

      assert_samba_password(user, password)

      assert_change_password_successfully(user.uid,
                                          password, new_password, *args)
      user.reload
      assert_samba_password(user, new_password)

      assert_change_password_with_wrong_current_password(user.uid,
                                                         new_password, *args)

      assert_change_password_successfully(user.uid, password, password,
                                          *args)
      user.reload
      assert_samba_password(user, password)
    end
  end

  private
  def change_password(name, old_password, new_password, *args)
    run_command_as_normal_user(name, *args) do |input, output|
      output.puts(old_password)
      output.puts(new_password)
      output.puts(new_password)
      output.flush
    end
  end

  def assert_samba_password(user, password)
    _wrap_assertion do
      assert_equal(Samba::Encrypt.lm_hash(password),
                   user.sambaLMPassword)
      assert_equal(Samba::Encrypt.ntlm_hash(password),
                   user.sambaNTPassword)
    end
  end

  def assert_change_password_successfully(name, old_password, new_password,
                                          *args)
    assert_equal([true,
                  [
                   "Enter your current password: ",
                   "New password: ",
                   "Retype new password: ",
                  ].join("\n") + "\n",
                 ],
                 change_password(name, old_password, new_password, *args))
  end

  def assert_change_password_with_wrong_current_password(name, password, *args)
    assert_equal([false,
                  [
                   "Enter your current password: ",
                   "password isn't match",
                  ].join("\n") + "\n",
                 ],
                 run_command_as_normal_user(name, *args) do |input, output|
                   output.puts(password)
                   output.flush
                 end)
  end
end
