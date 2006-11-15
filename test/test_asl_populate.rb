require 'asl-test-utils'

class AslPopulateTest < Test::Unit::TestCase
  include AslTestUtils

  def setup
    super
    @command = File.join(@bin_dir, "asl-populate")
  end

  def test_run_as_normal_user
    assert_equal([false, "", "need root authority.\n"],
                 run_command_as_normal_user)
  end

  def test_populate
    ActiveSambaLdap::Base.purge
    assert_equal([], ActiveSambaLdap::Base.search)
    assert_asl_populate_successfully("Administrator")
    base = ActiveSambaLdap::Base.base

    results = ActiveSambaLdap::Base.search

    config = ActiveSambaLdap::Base.configuration
    users_prefix = config[:users_prefix]
    groups_prefix = config[:groups_prefix]
    computers_prefix = config[:computers_prefix]
    idmap_prefix = config[:idmap_prefix]
    domain = config[:samba_domain]
    assert_equal([
                  nil,
                  users_prefix,
                  groups_prefix,
                  computers_prefix,
                  idmap_prefix,
                  "sambaDomainName=#{domain}",
                  "uid=Administrator,#{users_prefix}",
                  "uid=Guest,#{users_prefix}",
                  "cn=Users,#{groups_prefix}",
                  "cn=Account Operators,#{groups_prefix}",
                  "cn=Administrators,#{groups_prefix}",
                  "cn=Backup Operators,#{groups_prefix}",
                  "cn=Domain Admins,#{groups_prefix}",
                  "cn=Domain Computers,#{groups_prefix}",
                  "cn=Domain Guests,#{groups_prefix}",
                  "cn=Domain Users,#{groups_prefix}",
                  "cn=Guests,#{groups_prefix}",
                  "cn=Power Users,#{groups_prefix}",
                  "cn=Print Operators,#{groups_prefix}",
                  "cn=Replicators,#{groups_prefix}",
                  "cn=System Operators,#{groups_prefix}",
                 ].collect {|x| [x, base].compact.join(",")}.sort,
                 results.collect {|dn, attributes| dn}.sort)
  end

  def test_wrong_password
    ActiveSambaLdap::Base.purge
    assert_asl_populate_miss_match_password
  end

  private
  def assert_asl_populate_successfully(password, name=nil, *args)
    name ||= ActiveSambaLdap::User::DOMAIN_ADMIN_NAME
    assert_equal([true,
                  [
                   "Password for #{name}: ",
                   "Retype password for #{name}: ",
                  ].join("\n") + "\n",
                  "",
                 ],
                 run_command(*args) do |input, output|
                   output.puts(password)
                   output.puts(password)
                 end)
  end

  def assert_asl_populate_miss_match_password(name=nil, *args)
    name ||= ActiveSambaLdap::User::DOMAIN_ADMIN_NAME
    password = "password"
    assert_equal([false,
                  [
                   "Password for #{name}: ",
                   "Retype password for #{name}: ",
                  ].join("\n") + "\n",
                  "Passwords don't match.\n",
                 ],
                 run_command(*args) do |input, output|
                   output.puts(password)
                   output.puts(password + password.reverse)
                 end)
  end
end
