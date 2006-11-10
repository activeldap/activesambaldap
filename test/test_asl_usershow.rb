require 'test/unit'
require 'command_support'
require 'fileutils'

require 'active_samba_ldap'

class AslUserShowTest < Test::Unit::TestCase
  include CommandSupport
  include AslTestUtils

  def setup
    super
    @asl_usershow = File.join(@bin_dir, "asl-usershow")
  end

  def test_exist_user
    make_dummy_user do |user, password|
      assert_equal([true, user.to_s], run_asl_usershow(user.uid(true)))
    end
  end

  def test_not_exist_user
    assert_equal([false, "user 'not-exist' doesn't exist.\n"],
                 run_asl_usershow("not-exist"))
  end

  private
  def run_asl_usershow(*other_args, &block)
    run_ruby(*[@asl_usershow, *other_args], &block)
  end
end
