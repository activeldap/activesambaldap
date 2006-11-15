require 'asl-test-utils'

class GroupTest < Test::Unit::TestCase
  include AslTestUtils

  priority :must
  def test_builtin_group
    assert_sid("#{@group_class.configuration[:sid]}-543", 543)
    (544..552).each do |rid|
      assert_sid("S-1-5-32-#{rid}", rid)
    end
    assert_sid("#{@group_class.configuration[:sid]}-553", 553)
  end

  private
  def assert_sid(expected, rid)
    group = @group_class.new("XXX")
    group.change_sid(rid)
    assert_equal(expected, group.samba_sid)
  end
end
