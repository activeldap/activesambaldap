require 'asl-test-utils'

class AslGroupDelTest < Test::Unit::TestCase
  include AslTestUtils

  def setup
    super
    @command = File.join(@bin_dir, "asl-groupdel")
  end

  def test_run_as_normal_user
    assert_equal([false, "", _("need root authority.") + "\n"],
                 run_command_as_normal_user("group-name"))
  end

  def test_not_exist_group
    assert_equal([false, "", _("group doesn't exist: %s") % 'not-exist' + "\n"],
                 run_command("not-exist"))
  end

  def test_exist_group
    make_dummy_group do |group|
      assert_equal([true, "", ""], run_command(group.cn))
    end
  end

  def test_user_is_belonged_to
    make_dummy_group do |group|
      make_dummy_user do |user, password|
        group.users << user
        assert_equal([true, "", ""], run_command(group.cn))
      end
    end
  end

  def test_primary_group_of_user
    make_dummy_group do |group|
      make_dummy_user(:gid_number => group.gid_number) do |user, password|
        format = _("cannot destroy group '%s' due to members " \
                   "who belong to the group as primary group: %s")
        message = format % [group.cn, user.uid] + "\n"
        assert_equal([false, "", message], run_command(group.cn))
      end
    end
  end

  def test_primary_group_of_user_with_force
    make_dummy_group do |group|
      make_dummy_user(:gid_number => group.gid_number) do |user, password|
        format = _("cannot change primary group from '%s' " \
                   "to other group due to no other belonged groups: %s")
        message = format % [group.cn, user.uid] + "\n"
        assert_equal([false, "", message], run_command(group.cn, "--force"))
      end
    end
  end

  def test_primary_group_of_user_with_force_with_other_group
    make_dummy_group do |group|
      make_dummy_user(:gid_number => group.gid_number) do |user, password|
        make_dummy_group do |group2|
          group2.users << user
          assert_equal(group.gid_number, user.gid_number)
          assert_equal([true, "", ""], run_command(group.cn, "--force"))
          user.reload
          assert_equal(group2.gid_number, user.gid_number)
        end
      end
    end
  end

  def test_primary_group_of_user_with_other_group
    make_dummy_group do |group|
      make_dummy_user(:gid_number => group.gid_number) do |user, password|
        make_dummy_group do |group2|
          group2.users << user
          assert_equal(group.gid_number, user.gid_number)
          format = _("cannot destroy group '%s' due to members " \
                     "who belong to the group as primary group: %s")
          message = format % [group.cn, user.uid] + "\n"
          assert_equal([false, "", message], run_command(group.cn))
          user.reload
          assert_equal(group.gid_number, user.gid_number)
        end
      end
    end
  end
end
