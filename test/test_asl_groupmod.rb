require 'asl_test_utils'

class AslGroupModTest < Test::Unit::TestCase
  include AslTestUtils

  def setup
    super
    @command = File.join(@bin_dir, "asl-groupmod")
  end

  def test_not_exist_group
    assert_equal([false, "group 'not-exist' doesn't exist.\n"],
                 run_command("not-exist"))
  end

  def test_rename
    make_dummy_group do |group|
      old_cn = group.cn
      new_cn = "#{old_cn}-new"
      ensure_delete_group(new_cn) do
        assert(!@group_class.exists?(new_cn))

        args = ["--rename", new_cn]
        assert_asl_groupmod_successfully(group.cn, *args)

        assert(!@group_class.exists?(old_cn))
        assert(@group_class.exists?(new_cn))
      end
    end
  end

  def test_rename_with_members
    make_dummy_user do |user1, password1|
      make_dummy_user do |user2, password2|
        make_dummy_group do |group|
          group.add_member(user1)
          group.add_member(user2)

          old_cn = group.cn
          new_cn = "#{old_cn}-new"
          ensure_delete_group(new_cn) do
            assert(!@group_class.exists?(new_cn))

            args = ["--rename", new_cn]
            assert_asl_groupmod_successfully(group.cn, *args)

            assert(!@group_class.exists?(old_cn))
            assert(@group_class.exists?(new_cn))

            members = []
            new_group = @group_class.find(new_cn)
            new_group.memberUid(true).each do |uid|
              members.concat(@user_class.find(:all,
                                              :attribute => "uid",
                                              :value => uid))
            end
            assert_equal([user1.uid, user2.uid].sort,
                         members.collect {|m| m.uid}.sort)
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

          old_cn = group.cn
          new_cn = "#{old_cn}-new"
          ensure_delete_group(new_cn) do
            assert(!@group_class.exists?(new_cn))

            args = ["--rename", new_cn]
            assert_asl_groupmod_successfully(group.cn, *args)

            assert(!@group_class.exists?(old_cn))
            assert(@group_class.exists?(new_cn))

            new_group = @group_class.find(new_cn)
            assert_equal(new_group.gidNumber, user1.gidNumber)
            assert_equal(new_group.gidNumber, user2.gidNumber)
          end
        end
      end
    end
  end

  def test_gid_number
    make_dummy_group do |group|
      old_gid_number = group.gidNumber
      old_samba_sid = group.sambaSID
      new_gid_number = old_gid_number.succ

      old_rid = (2 * Integer(old_gid_number) + 1001).to_s
      new_rid = (2 * Integer(new_gid_number) + 1001).to_s
      new_samba_sid = old_samba_sid.sub(/#{Regexp.escape(old_rid)}$/, new_rid)

      args = ["--gid", new_gid_number]
      assert_asl_groupmod_successfully(group.cn, *args)

      new_group = @group_class.find(group.cn)
      assert_equal(new_gid_number, new_group.gidNumber)
      assert_equal(new_samba_sid, new_group.sambaSID)
    end
  end

  def test_gid_number_non_unique
    make_dummy_group do |group|
      old_gid_number = group.gidNumber
      make_dummy_group do |group2|
        new_gid_number = group2.gidNumber

        old_samba_sid = group.sambaSID
        old_rid = (2 * Integer(old_gid_number) + 1001).to_s
        new_rid = (2 * Integer(new_gid_number) + 1001).to_s
        new_samba_sid = old_samba_sid.sub(/#{Regexp.escape(old_rid)}$/, new_rid)

        message = "gid number '#{new_gid_number}' already exists\n"
        args = ["--gid", new_gid_number]
        assert_asl_groupmod_failed(group.cn, message, *args)

        new_group = @group_class.find(group.cn)
        assert_equal(old_gid_number, new_group.gidNumber)
        assert_equal(old_samba_sid, new_group.sambaSID)
      end
    end
  end

  def test_gid_number_allow_non_unique
    make_dummy_group do |group|
      old_gid_number = group.gidNumber
      make_dummy_group do |group2|
        new_gid_number = group2.gidNumber

        old_samba_sid = group.sambaSID
        old_rid = (2 * Integer(old_gid_number) + 1001).to_s
        new_rid = (2 * Integer(new_gid_number) + 1001).to_s
        new_samba_sid = old_samba_sid.sub(/#{Regexp.escape(old_rid)}$/, new_rid)

        args = ["--gid", new_gid_number, "--allow-non-unique-gid"]
        assert_asl_groupmod_successfully(group.cn, *args)

        new_group = @group_class.find(group.cn)
        assert_equal(new_gid_number, new_group.gidNumber)
        assert_equal(new_samba_sid, new_group.sambaSID)
      end
    end
  end

  def test_add_members
    make_dummy_group do |group|
      make_dummy_user do |user1, password1|
        make_dummy_user do |user2, password2|
          make_dummy_user do |user3, password3|
            old_member_uids = group.memberUid(true)

            new_members = [user1.uid, user2.uid]
            args = ["--add-members", new_members.join(",")]
            assert_asl_groupmod_successfully(group.cn, *args)

            new_group = @group_class.find(group.cn)
            new_member_uids = new_group.memberUid(true)

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

            old_member_uids = group.memberUid(true)

            members_to_delete = [user1.uid, user2.uid]
            args = ["--delete-members", members_to_delete.join(",")]
            assert_asl_groupmod_successfully(group.cn, *args)

            new_group = @group_class.find(group.cn)
            new_member_uids = new_group.memberUid(true)

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

            old_member_uids = group.memberUid(true)

            new_members = [user2.uid, user3.uid]
            args = ["--add-members", new_members.join(","),
                    "--delete-members", old_member_uids.join(",")]
            assert_asl_groupmod_successfully(group.cn, *args)

            new_group = @group_class.find(group.cn)
            new_member_uids = new_group.memberUid(true)

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
      assert_asl_groupmod_failed(group.cn,
                                 "#{base} user\n",
                                 "--add-members", "user",
                                 "--delete-members", "user")

      assert_asl_groupmod_failed(group.cn,
                                 "#{base} user2\n",
                                 "--add-members", "user1,user2,user3",
                                 "--delete-members", "user2")

      assert_asl_groupmod_failed(group.cn,
                                 "#{base} user2, user3\n",
                                 "--add-members", "user1,user2,user3",
                                 "--delete-members", "user2,user3,user4")
    end
  end

  private
  def assert_asl_groupmod_successfully(name, *args)
    args << name
    assert_equal([true, ""], run_command(*args))
  end

  def assert_asl_groupmod_failed(name, message, *args)
    args << name
    assert_equal([false, message], run_command(*args))
  end
end
