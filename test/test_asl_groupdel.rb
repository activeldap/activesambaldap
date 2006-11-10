require 'test/unit'
require 'command_support'
require 'fileutils'

require 'active_samba_ldap'

class AslGroupDelTest < Test::Unit::TestCase
  include CommandSupport
  include AslTestUtils

  def setup
    super
    @asl_groupdel = File.join(@bin_dir, "asl-groupdel")
  end

  def test_run_as_normal_user
    assert_equal([false, "need root authority.\n"],
                 run_asl_groupdel_as_normal_user("group-name"))
  end

  def test_not_exist_group
    assert_equal([false, "group 'not-exist' doesn't exist.\n"],
                 run_asl_groupdel("not-exist"))
  end

  def test_exist_group
    make_dummy_group do |group|
      assert_equal([true, ""], run_asl_groupdel(group.cn(true)))
    end
  end

  def test_user_is_belonged_to
    make_dummy_group do |group|
      make_dummy_user do |user, password|
        group.add_member(user)
        assert_equal([true, ""], run_asl_groupdel(group.cn(true)))
      end
    end
  end

  def test_primary_group_of_user
    make_dummy_group do |group|
      make_dummy_user(:gid_number => group.gidNumber(true)) do |user, password|
        message = "cannot destroy group '#{group.cn(true)}' due to members "
        message << "who belong to the group as primary group"
        message << ": #{user.uid(true)}\n"
        assert_equal([false, message], run_asl_groupdel(group.cn(true)))
      end
    end
  end

  def test_primary_group_of_user_with_force
    make_dummy_group do |group|
      make_dummy_user(:gid_number => group.gidNumber(true)) do |user, password|
        message = "cannot change primary group from '#{group.cn(true)}' "
        message << "to other group due to no other belonged groups"
        message << ": #{user.uid(true)}\n"
        assert_equal([false, message], run_asl_groupdel(group.cn(true),
                                                        "--force"))
      end
    end
  end

  def test_primary_group_of_user_with_force_with_other_group
    make_dummy_group do |group|
      make_dummy_user(:gid_number => group.gidNumber(true)) do |user, password|
        make_dummy_group do |group2|
          group2.add_member(user)
          assert_equal(group.gidNumber(true), user.gidNumber(true))
          assert_equal([true, ""], run_asl_groupdel(group.cn(true), "--force"))
          user = @user_class.new(user.uid(true))
          assert_equal(group2.gidNumber(true), user.gidNumber(true))
        end
      end
    end
  end

  def test_primary_group_of_user_with_other_group
    make_dummy_group do |group|
      make_dummy_user(:gid_number => group.gidNumber(true)) do |user, password|
        make_dummy_group do |group2|
          group2.add_member(user)
          assert_equal(group.gidNumber(true), user.gidNumber(true))
          message = "cannot destroy group '#{group.cn(true)}' due to members "
          message << "who belong to the group as primary group"
          message << ": #{user.uid(true)}\n"
          assert_equal([false, message], run_asl_groupdel(group.cn(true)))
          user = @user_class.new(user.uid(true))
          assert_equal(group.gidNumber(true), user.gidNumber(true))
        end
      end
    end
  end

  private
  def run_asl_groupdel(*other_args, &block)
    run_ruby_with_fakeroot(*[@asl_groupdel, *other_args], &block)
  end

  def run_asl_groupdel_as_normal_user(*other_args, &block)
    run_ruby(*[@asl_groupdel, *other_args], &block)
  end
end
