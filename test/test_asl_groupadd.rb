require 'asl-test-utils'

class AslGroupAddTest < Test::Unit::TestCase
  include AslTestUtils

  def setup
    super
    @command = File.join(@bin_dir, "asl-groupadd")
  end

  def test_run_as_normal_user
    assert_equal([false, "need root authority.\n"],
                 run_command_as_normal_user("group-name"))
  end

  def test_exist_group
    make_dummy_group do |group|
      assert(@group_class.exists?(group.cn))
      assert_equal([false, "group '#{group.cn}' already exists.\n"],
                   run_command(group.cn))
      assert(@group_class.exists?(group.cn))
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
  def assert_asl_groupadd_successfully(name, message=nil, *args)
    _wrap_assertion do
      assert(!@group_class.exists?(name))
      args << name
      assert_equal([true, "#{message}"], run_command(*args))
      assert(@group_class.exists?(name))
    end
  end

  def assert_asl_groupadd_failed(name, message, *args)
    _wrap_assertion do
      assert(!@group_class.exists?(name))
      args << name
      assert_equal([false, message], run_command(*args))
      assert(!@group_class.exists?(name))
    end
  end
end
