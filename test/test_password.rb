require 'asl-test-utils'

class PasswordTest < Test::Unit::TestCase
  include AslTestUtils

  priority :must
  def test_password_hash_type
    %w(crypt md5 smd5 sha ssha).each do |type|
      assert_valid_password_hash_type(type) do |klass, normalized_type|
        user = klass.new("XXX")
        user.change_password("password")
        assert_match(/^\{#{Regexp.escape(normalized_type.to_s.upcase)}\}/,
                     user.user_password)
      end
    end
  end

  def test_validate_password_hash_type
    %w(crypt md5 smd5 sha ssha).each do |type|
      assert_valid_password_hash_type(type)
      assert_valid_password_hash_type(type.to_sym)
      assert_valid_password_hash_type(type.upcase)
      assert_valid_password_hash_type(type.capitalize)
    end

    assert_invalid_password_hash_type("XXX")
  end

  private
  def assert_valid_password_hash_type(type)
    klass = Class.new(@user_class)
    assert_nothing_raised do
      configuration = reference_configuration.merge(:password_hash_type => type)
      klass.setup_connection(configuration)
      klass.ldap_mapping
    end
    yield(klass, klass.configuration[:password_hash_type]) if block_given?
  ensure
    klass.remove_connection
  end

  def assert_invalid_password_hash_type(type)
    klass = Class.new(@user_class)
    assert_raises(ActiveSambaLdap::InvalidConfigurationValueError) do
      configuration = reference_configuration.merge(:password_hash_type => type)
      klass.setup_connection(configuration)
    end
  ensure
    klass.remove_connection
  end
end
