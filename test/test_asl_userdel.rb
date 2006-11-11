require 'asl_test_utils'

class AslUserDelTest < Test::Unit::TestCase
  include AslTestUtils

  def setup
    super
    @command = File.join(@bin_dir, "asl-userdel")
  end

  def test_run_as_normal_user
    assert_equal([false, "need root authority.\n"],
                 run_command_as_normal_user("user-name"))
  end

  def test_not_exist_user
    assert_equal([false, "user 'not-exist' doesn't exist.\n"],
                 run_command("not-exist"))
  end

  def test_exist_user
    make_dummy_user do |user, password|
      assert(File.exist?(user.homeDirectory))
      assert_equal([true, ""], run_command(user.uid))
      assert(File.exist?(user.homeDirectory))
    end
  end

  def test_belong_to_group
    make_dummy_user do |user, password|
      assert(File.exist?(user.homeDirectory))
      make_dummy_group do |group|
        group.add_member(user)
        assert_equal([true, ""], run_command(user.uid))
      end
      assert(File.exist?(user.homeDirectory))
    end
  end

  def test_remove_home_directory
    make_dummy_user do |user, password|
      assert(File.exist?(user.homeDirectory))
      assert_equal([true, ""], run_command("-r", user.uid))
      assert(!File.exist?(user.homeDirectory))
    end
  end
end
