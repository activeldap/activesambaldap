require 'asl-test-utils'

class EntryTest < Test::Unit::TestCase
  include AslTestUtils

  priority :must
  def test_entry_create
    name = "temporary-user"
    user = @user_class.create(:uid => name)
    assert(@user_class.exists?(name))
    assert_equal(ActiveSambaLdap::Group::DOMAIN_USERS_RID.to_s,
                 user.primary_group.gid_number)
  ensure
    user.destroy if user
  end
end
