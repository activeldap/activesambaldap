require 'asl-test-utils'

class AslUserShowTest < Test::Unit::TestCase
  include AslTestUtils

  def setup
    super
    @command = File.join(@bin_dir, "asl-usershow")
  end

  def test_exist_user
    make_dummy_user do |user, password|
      user.class.establish_connection("reference")
      begin
        user = user.class.find(user.uid)
        assert_equal([true, user.to_ldif], run_command(user.uid))
      ensure
        user.class.establish_connection("update")
      end
    end
  end

  def test_not_exist_user
    assert_equal([false, "user 'not-exist' doesn't exist.\n"],
                 run_command("not-exist"))
  end
end
