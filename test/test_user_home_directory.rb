require 'asl-test-utils'

class UserHomeDirectoryTest < Test::Unit::TestCase
  include AslTestUtils

  priority :must
  def test_validate_user_home_directory_mode
    assert_valid_user_home_directory_mode(0700) do |klass, mode|
      assert_equal(0700, mode)
    end
    assert_valid_user_home_directory_mode("0750") do |klass, mode|
      assert_equal(0750, mode)
    end
    assert_valid_user_home_directory_mode(nil) do |klass, mode|
      assert_equal(0755, mode)
    end

    assert_invalid_user_home_directory_mode("XXX")
  end

  private
  def assert_valid_user_home_directory_mode(type)
    klass = Class.new(@user_class)
    assert_nothing_raised do
      config = reference_configuration.merge(:user_home_directory_mode => type)
      klass.establish_connection(config)
      klass.ldap_mapping
    end
    yield(klass, klass.configuration[:user_home_directory_mode]) if block_given?
  ensure
    klass.remove_connection
  end

  def assert_invalid_user_home_directory_mode(type)
    klass = Class.new(@user_class)
    assert_raises(ActiveSambaLdap::InvalidConfigurationValueError) do
      config = reference_configuration.merge(:user_home_directory_mode => type)
      klass.establish_connection(config)
    end
  ensure
    klass.remove_connection
  end
end
