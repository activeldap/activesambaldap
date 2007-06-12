require 'asl-test-utils'

class EntryTest < Test::Unit::TestCase
  include AslTestUtils

  priority :must
  def test_entry_create
    assert_created_user("temporary-user1", false)
    assert_created_user("temporary-user2", true)
  end

  private
  def assert_created_user(name, stringify)
    params = {:uid => name}
    params = params.stringify_keys if stringify
    user = @user_class.create(params)
    assert(@user_class.exists?(name))
    assert_equal(ActiveSambaLdap::Group::DOMAIN_USERS_RID.to_s,
                 user.primary_group.gid_number)
  end
end
