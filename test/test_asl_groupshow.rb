require 'test/unit'
require 'command_support'
require 'fileutils'

require 'active_samba_ldap'

class AslGroupShowTest < Test::Unit::TestCase
  include CommandSupport
  include AslTestUtils

  def setup
    super
    @asl_groupshow = File.join(@bin_dir, "asl-groupshow")
  end

  def test_exist_group
    make_dummy_group do |group|
      assert_equal([true, group.to_s], run_asl_groupshow(group.cn(true)))
    end
  end

  def test_not_exist_group
    assert_equal([false, "group 'not-exist' doesn't exist.\n"],
                 run_asl_groupshow("not-exist"))
  end

  private
  def run_asl_groupshow(*other_args, &block)
    run_ruby(*[@asl_groupshow, *other_args], &block)
  end
end
