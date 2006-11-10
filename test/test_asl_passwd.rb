require 'test/unit'
require 'command_support'
require 'asl_test_utils'

require 'active_samba_ldap'

class AslPasswdTest < Test::Unit::TestCase
  include CommandSupport
  include AslTestUtils

  def setup
    super
    @asl_passwd = File.join(@bin_dir, "asl-passwd")
  end

  def teardown
    ActiveSambaLdap::Base.close
  end

  def test_unknown_user
    assert_equal([false, "user 'unknown' doesn't exist.\n"],
                 run_asl_passwd("unknown"))
  end

  def test_change_password
    make_dummy_user do |user, password|
      new_password = "new#{password}"

      assert_samba_password(user, password)

      assert_change_password_successfully(user.uid(true),
                                          password, new_password)

      user = @user_class.new(user.uid(true))
      assert_samba_password(user, new_password)

      assert_change_password_with_wrong_current_password(user.uid(true),
                                                         password)

      assert_change_password_successfully(user.uid(true),
                                          new_password, password)
      user = @user_class.new(user.uid(true))
      assert_samba_password(user, password)
    end
  end

  def test_change_password_only_unix
    make_dummy_user do |user, password|
      new_password = "new#{password}"
      args = ["--no-samba-password"]

      assert_samba_password(user, password)

      assert_change_password_successfully(user.uid(true),
                                          password, new_password,
                                          *args)
      user = @user_class.new(user.uid(true))
      assert_samba_password(user, password)

      assert_change_password_with_wrong_current_password(user.uid(true),
                                                         password, *args)

      assert_change_password_successfully(user.uid(true),
                                          new_password, password, *args)
      user = @user_class.new(user.uid(true))
      assert_samba_password(user, password)
    end
  end

  def test_change_password_only_samba
    make_dummy_user do |user, password|
      new_password = "new#{password}"
      args = ["--no-unix-password"]

      assert_samba_password(user, password)

      assert_change_password_successfully(user.uid(true),
                                          password, new_password, *args)
      user = @user_class.new(user.uid(true))
      assert_samba_password(user, new_password)

      assert_change_password_with_wrong_current_password(user.uid(true),
                                                         new_password, *args)

      assert_change_password_successfully(user.uid(true), password, password,
                                          *args)
      user = @user_class.new(user.uid(true))
      assert_samba_password(user, password)
    end
  end

  private
  def run_asl_passwd(*other_args, &block)
    run_ruby(*[@asl_passwd, *other_args], &block)
  end

  def change_password(name, old_password, new_password, *args)
    run_asl_passwd(name, *args) do |input, output|
      output.puts(old_password)
      output.puts(new_password)
      output.puts(new_password)
      output.flush
    end
  end

  def assert_samba_password(user, password)
    _wrap_assertion do
      assert_equal(Samba::Encrypt.lm_hash(password),
                   user.sambaLMPassword(true))
      assert_equal(Samba::Encrypt.ntlm_hash(password),
                   user.sambaNTPassword(true))
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
                 run_asl_passwd(name, *args) do |input, output|
                   output.puts(password)
                   output.flush
                 end)
  end
end
