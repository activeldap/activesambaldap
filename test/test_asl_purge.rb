require 'asl-test-utils'

class AslPurgeTest < Test::Unit::TestCase
  include AslTestUtils

  def setup
    super
    @command = File.join(@bin_dir, "asl-purge")
  end

  def test_run_as_normal_user
    assert_equal([false, "", "need root authority.\n"],
                 run_command_as_normal_user)
  end

  def test_populate
    assert_not_equal([], ActiveSambaLdap::Base.search)
    assert_equal([true, "", ""], run_command)
    assert_equal([], ActiveSambaLdap::Base.search)
  end
end
