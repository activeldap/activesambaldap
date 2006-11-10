require 'test/unit'
require 'command_support'
require 'fileutils'

require 'active_samba_ldap'

class AslUserDelTest < Test::Unit::TestCase
  include CommandSupport
  include AslTestUtils

  def setup
    super
    @asl_userdel = File.join(@bin_dir, "asl-userdel")
  end

  def test_run_as_normal_user
    assert_equal([false, "need root authority.\n"],
                 run_asl_userdel_as_normal_user("user-name"))
  end

  def test_not_exist_user
    assert_equal([false, "user 'not-exist' doesn't exist.\n"],
                 run_asl_userdel("not-exist"))
  end

  def test_exist_user
    make_dummy_user do |user, password|
      assert(File.exist?(user.homeDirectory(true)))
      assert_equal([true, ""], run_asl_userdel(user.uid))
      assert(File.exist?(user.homeDirectory(true)))
    end
  end

  def test_belong_to_group
    make_dummy_user do |user, password|
      assert(File.exist?(user.homeDirectory(true)))
      make_dummy_group do |group|
        group.add_member(user)
        assert_equal([true, ""], run_asl_userdel(user.uid))
      end
      assert(File.exist?(user.homeDirectory(true)))
    end
  end

  def test_remove_home_directory
    make_dummy_user do |user, password|
      assert(File.exist?(user.homeDirectory(true)))
      assert_equal([true, ""], run_asl_userdel("-r", user.uid))
      assert(!File.exist?(user.homeDirectory(true)))
    end
  end

  private
  def run_asl_userdel(*other_args, &block)
    run_ruby_with_fakeroot(*[@asl_userdel, *other_args], &block)
  end

  def run_asl_userdel_as_normal_user(*other_args, &block)
    run_ruby(*[@asl_userdel, *other_args], &block)
  end
end
