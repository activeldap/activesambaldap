require 'test/unit'
require 'command_support'
require 'asl_test_utils'
require 'fileutils'
require 'time'

require 'active_samba_ldap'

class AslGroupModTest < Test::Unit::TestCase
  include CommandSupport
  include AslTestUtils

  def setup
    super
    @asl_groupmod = File.join(@bin_dir, "asl-groupmod")
  end

  def test_not_exist_group
    assert_equal([false, "group 'not-exist' doesn't exist.\n"],
                 run_asl_groupmod("not-exist"))
  end

  def test_rename
    make_dummy_group do |group|
      old_cn = group.cn(true)
      new_cn = "#{old_cn}-new"
      ensure_delete_group(new_cn) do
        new_group = @group_class.new(new_cn)
        assert(!new_group.exists?)

        args = ["--rename", new_cn]
        assert_asl_groupmod_successfully(group.cn(true), *args)

        old_group = @group_class.new(old_cn)
        assert(!old_group.exists?)
        new_group = @group_class.new(new_cn)
        assert(new_group.exists?)
      end
    end
  end

  def test_rename_with_members
    make_dummy_user do |user1, password1|
      make_dummy_user do |user2, password2|
        make_dummy_group do |group|
          group.add_member(user1)
          group.add_member(user2)

          old_cn = group.cn(true)
          new_cn = "#{old_cn}-new"
          ensure_delete_group(new_cn) do
            new_group = @group_class.new(new_cn)
            assert(!new_group.exists?)

            args = ["--rename", new_cn]
            assert_asl_groupmod_successfully(group.cn(true), *args)

            old_group = @group_class.new(old_cn)
            assert(!old_group.exists?)
            new_group = @group_class.new(new_cn)
            assert(new_group.exists?)

            members = []
            new_group.memberUid.each do |uid|
              members.concat(@user_class.find_all(:attribute => "uid",
                                                  :value => uid))
            end
            assert_equal([user1.uid(true), user2.uid(true)].sort,
                         members.sort)
          end
        end
      end
    end
  end

  def test_rename_with_members_primary
    make_dummy_user do |user1, password1|
      make_dummy_user do |user2, password2|
        make_dummy_group do |group|
          user1.change_group(group)
          user2.change_group(group)

          old_cn = group.cn(true)
          new_cn = "#{old_cn}-new"
          ensure_delete_group(new_cn) do
            new_group = @group_class.new(new_cn)
            assert(!new_group.exists?)

            args = ["--rename", new_cn]
            assert_asl_groupmod_successfully(group.cn(true), *args)

            old_group = @group_class.new(old_cn)
            assert(!old_group.exists?)
            new_group = @group_class.new(new_cn)
            assert(new_group.exists?)

            assert_equal(new_group.gidNumber, user1.gidNumber)
            assert_equal(new_group.gidNumber, user2.gidNumber)
          end
        end
      end
    end
  end

  def test_gid_number
    make_dummy_group do |group|
      old_gid_number = group.gidNumber(true)
      old_samba_sid = group.sambaSID(true)
      new_gid_number = old_gid_number.succ

      old_rid = (2 * Integer(old_gid_number) + 1001).to_s
      new_rid = (2 * Integer(new_gid_number) + 1001).to_s
      new_samba_sid = old_samba_sid.sub(/#{Regexp.escape(old_rid)}$/, new_rid)

      args = ["--gid", new_gid_number]
      assert_asl_groupmod_successfully(group.cn(true), *args)

      new_group = @group_class.new(group.cn(true))
      assert_equal(new_gid_number, new_group.gidNumber(true))
      assert_equal(new_samba_sid, new_group.sambaSID(true))
    end
  end

  def test_gid_number_non_unique
    make_dummy_group do |group|
      old_gid_number = group.gidNumber(true)
      make_dummy_group do |group2|
        new_gid_number = group2.gidNumber(true)

        old_samba_sid = group.sambaSID(true)
        old_rid = (2 * Integer(old_gid_number) + 1001).to_s
        new_rid = (2 * Integer(new_gid_number) + 1001).to_s
        new_samba_sid = old_samba_sid.sub(/#{Regexp.escape(old_rid)}$/, new_rid)

        message = "gid number '#{new_gid_number}' already exists\n"
        args = ["--gid", new_gid_number]
        assert_asl_groupmod_failed(group.cn(true), message, *args)

        new_group = @group_class.new(group.cn(true))
        assert_equal(old_gid_number, new_group.gidNumber(true))
        assert_equal(old_samba_sid, new_group.sambaSID(true))
      end
    end
  end

  def test_gid_number_allow_non_unique
    make_dummy_group do |group|
      old_gid_number = group.gidNumber(true)
      make_dummy_group do |group2|
        new_gid_number = group2.gidNumber(true)

        old_samba_sid = group.sambaSID(true)
        old_rid = (2 * Integer(old_gid_number) + 1001).to_s
        new_rid = (2 * Integer(new_gid_number) + 1001).to_s
        new_samba_sid = old_samba_sid.sub(/#{Regexp.escape(old_rid)}$/, new_rid)

        args = ["--gid", new_gid_number, "--allow-non-unique-gid"]
        assert_asl_groupmod_successfully(group.cn(true), *args)

        new_group = @group_class.new(group.cn(true))
        assert_equal(new_gid_number, new_group.gidNumber(true))
        assert_equal(new_samba_sid, new_group.sambaSID(true))
      end
    end
  end

  def test_add_members
    make_dummy_group do |group|
      make_dummy_user do |user1, password1|
        make_dummy_user do |user2, password2|
          make_dummy_user do |user3, password3|
            old_member_uids = group.memberUid

            new_members = [user1.uid(true), user2.uid(true)]
            args = ["--add-members", new_members.join(",")]
            assert_asl_groupmod_successfully(group.cn(true), *args)

            new_group = @group_class.new(group.cn(true))
            new_member_uids = new_group.memberUid

            assert_equal(new_members.sort,
                         (new_member_uids - old_member_uids).sort)
          end
        end
      end
    end
  end

  def test_delete_members
    make_dummy_group do |group|
      make_dummy_user do |user1, password1|
        make_dummy_user do |user2, password2|
          make_dummy_user do |user3, password3|
            group.add_member(user1)
            group.add_member(user2)
            group.add_member(user3)

            old_member_uids = group.memberUid

            members_to_delete = [user1.uid(true), user2.uid(true)]
            args = ["--delete-members", members_to_delete.join(",")]
            assert_asl_groupmod_successfully(group.cn(true), *args)

            new_group = @group_class.new(group.cn(true))
            new_member_uids = new_group.memberUid

            assert_equal(members_to_delete.sort,
                         (old_member_uids - new_member_uids).sort)
          end
        end
      end
    end
  end

  def test_add_and_delete_members
    make_dummy_group do |group|
      make_dummy_user do |user1, password1|
        make_dummy_user do |user2, password2|
          make_dummy_user do |user3, password3|
            group.add_member(user1)

            old_member_uids = group.memberUid

            new_members = [user2.uid(true), user3.uid(true)]
            args = ["--add-members", new_members.join(","),
                    "--delete-members", old_member_uids.join(",")]
            assert_asl_groupmod_successfully(group.cn(true), *args)

            new_group = @group_class.new(group.cn(true))
            new_member_uids = new_group.memberUid

            assert_equal(new_members.sort,
                         (new_member_uids - old_member_uids).sort)
          end
        end
      end
    end
  end

  def test_duplicate_members
    make_dummy_group do |group|
      base = "there are duplicated members in adding and deleting members:"
      assert_asl_groupmod_failed(group.cn(true),
                                 "#{base} user\n",
                                 "--add-members", "user",
                                 "--delete-members", "user")

      assert_asl_groupmod_failed(group.cn(true),
                                 "#{base} user2\n",
                                 "--add-members", "user1,user2,user3",
                                 "--delete-members", "user2")

      assert_asl_groupmod_failed(group.cn(true),
                                 "#{base} user2, user3\n",
                                 "--add-members", "user1,user2,user3",
                                 "--delete-members", "user2,user3,user4")
    end
  end

  private
  def run_asl_groupmod(*other_args, &block)
    run_ruby_with_fakeroot(*[@asl_groupmod, *other_args], &block)
  end

  def run_asl_groupmod_as_normal_user(*other_args, &block)
    run_ruby(*[@asl_groupmod, *other_args], &block)
  end

  def assert_asl_groupmod_successfully(name, *args)
    args << name
    assert_equal([true, ""], run_asl_groupmod(*args))
  end

  def assert_asl_groupmod_failed(name, message, *args)
    args << name
    assert_equal([false, message], run_asl_groupmod(*args))
  end
end
