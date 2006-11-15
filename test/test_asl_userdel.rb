require 'asl-test-utils'

class AslUserDelTest < Test::Unit::TestCase
  include AslTestUtils

  def setup
    super
    @command = File.join(@bin_dir, "asl-userdel")
  end

  def test_run_as_normal_user
    assert_equal([false, "", "need root authority.\n"],
                 run_command_as_normal_user("user-name"))
  end

  def test_not_exist_user
    assert_equal([false, "", "user 'not-exist' doesn't exist.\n"],
                 run_command("not-exist"))
  end

  def test_exist_user
    make_dummy_user do |user, password|
      assert(File.exist?(user.home_directory))
      assert_equal([true, "", ""], run_command(user.uid))
      assert(!@user_class.exists?(user.uid))
      assert(File.exist?(user.home_directory))
    end
  end

  def test_exist_computer
    make_dummy_computer do |computer, password|
      assert(@computer_class.exists?(computer.uid))
      assert_equal([true, "", ""],
                   run_command(computer.uid, '--computer-account'))
      assert(!@computer_class.exists?(computer.uid))
    end
  end

  def test_user_as_computer
    make_dummy_user do |user, password|
      assert_equal([false, "", "computer '#{user.uid}$' doesn't exist.\n"],
                   run_command(user.uid, "--computer-account"))
      assert(@user_class.exists?(user.uid))
    end
  end

  def test_computer_as_user
    make_dummy_computer do |computer, password|
      assert_equal([false, "", "user '#{computer.uid}' doesn't exist.\n"],
                   run_command(computer.uid))
      assert(@computer_class.exists?(computer.uid))
    end
  end

  def test_belongs_to_group
    make_dummy_user do |user, password|
      assert(File.exist?(user.home_directory))
      make_dummy_group do |group|
        group.users << user
        assert_equal([true, "", ""], run_command(user.uid))
      end
      assert(File.exist?(user.home_directory))
    end
  end

  def test_remove_home_directory
    make_dummy_user do |user, password|
      assert(File.exist?(user.home_directory))
      assert_equal([true, "", ""], run_command("-r", user.uid))
      assert(!File.exist?(user.home_directory))
    end
  end
end
