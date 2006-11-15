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
    users_suffix = config[:users_suffix]
    groups_suffix = config[:groups_suffix]
    computers_suffix = config[:computers_suffix]
    idmap_suffix = config[:idmap_suffix]
    domain = config[:samba_domain]
    assert_equal([
                  nil,
                  users_suffix,
                  groups_suffix,
                  computers_suffix,
                  idmap_suffix,
                  "sambaDomainName=#{domain}",
                  "uid=Administrator,#{users_suffix}",
                  "uid=Guest,#{users_suffix}",
                  "cn=Users,#{groups_suffix}",
                  "cn=Account Operators,#{groups_suffix}",
                  "cn=Administrators,#{groups_suffix}",
                  "cn=Backup Operators,#{groups_suffix}",
                  "cn=Domain Admins,#{groups_suffix}",
                  "cn=Domain Computers,#{groups_suffix}",
                  "cn=Domain Guests,#{groups_suffix}",
                  "cn=Domain Users,#{groups_suffix}",
                  "cn=Guests,#{groups_suffix}",
                  "cn=Power Users,#{groups_suffix}",
                  "cn=Print Operators,#{groups_suffix}",
                  "cn=Replicators,#{groups_suffix}",
                  "cn=System Operators,#{groups_suffix}",
                 ].collect {|x| [x, base].compact.join(",")}.sort,
                 results.collect {|dn, attributes| dn}.sort)
  end

  def test_wrong_password
    ActiveSambaLdap::Base.purge
    assert_asl_populate_miss_match_password
  end

  private
  def assert_asl_populate_successfully(password, name=nil, *args)
    name ||= @user_class::DOMAIN_ADMIN_NAME
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
    name ||= @user_class::DOMAIN_ADMIN_NAME
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
