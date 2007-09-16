require 'asl-test-utils'

class AslGroupShowTest < Test::Unit::TestCase
  include AslTestUtils

  def setup
    super
    @command = File.join(@bin_dir, "asl-groupshow")
  end

  def test_exist_group
    make_dummy_group do |group|
      assert_equal([true, group.to_ldif, ""], run_command(group.cn))
    end
  end

  def test_not_exist_group
    assert_equal([false, "", _("group doesn't exist: %s") % 'not-exist' + "\n"],
                 run_command("not-exist"))
  end
end
