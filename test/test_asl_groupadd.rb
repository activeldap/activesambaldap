require 'test/unit'
require 'command_support'
require 'asl_test_utils'
require 'fileutils'
require 'time'
require 'tmpdir'

require 'active_samba_ldap'

class AslGroupAddTest < Test::Unit::TestCase
  include CommandSupport
  include AslTestUtils

  def setup
    super
    @asl_groupadd = File.join(@bin_dir, "asl-groupadd")
  end

  def test_run_as_normal_user
    assert_equal([false, "need root authority.\n"],
                 run_asl_groupadd_as_normal_user("group-name"))
  end

  def test_exist_group
    make_dummy_group do |group|
      assert(@group_class.new(group.cn).exists?)
      assert_equal([false, "group '#{group.cn}' already exists.\n"],
                   run_asl_groupadd(group.cn(true)))
      assert(@group_class.new(group.cn).exists?)
    end
  end

  def test_add_group
    ensure_delete_group("test-group") do |cn|
      assert_asl_groupadd_successfully(cn)
    end
  end

  def test_specify_gid
    ensure_delete_group("test-group") do |cn|
      gid_number = "11111"
      assert_asl_groupadd_successfully(cn, "#{gid_number}\n",
                                       "--print-gid-number",
                                       "--gid", gid_number)
    end
  end

  def test_print_gid_number
    ensure_delete_group("test-group") do |cn|
      pool_class = Class.new(ActiveSambaLdap::UnixIdPool)
      pool_class.ldap_mapping
      pool = pool_class.new(ActiveSambaLdap::Config.samba_domain)
      next_gid = @group_class.find_available_gid_number(pool)
      assert_asl_groupadd_successfully(cn, "#{next_gid}\n",
                                       "--print-gid-number")
    end
  end

  private
  def run_asl_groupadd(*other_args, &block)
    run_ruby_with_fakeroot(*[@asl_groupadd, *other_args], &block)
  end

  def run_asl_groupadd_as_normal_user(*other_args, &block)
    run_ruby(*[@asl_groupadd, *other_args], &block)
  end

  def assert_asl_groupadd_successfully(name, message=nil, *args)
    _wrap_assertion do
      assert(!@group_class.new(name).exists?)
      args << name
      assert_equal([true, "#{message}"], run_asl_groupadd(*args))
      assert(@group_class.new(name).exists?)
    end
  end

  def assert_asl_groupadd_failed(name, message, *args)
    _wrap_assertion do
      assert(!@group_class.new(name).exists?)
      args << name
      assert_equal([false, message], run_asl_groupadd(*args))
      assert(!@group_class.new(name).exists?)
    end
  end
end
