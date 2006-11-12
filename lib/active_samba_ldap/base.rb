module ActiveSambaLdap
  class Error < StandardError
  end

  class RequiredVariableIsNotSet < Error
    attr_reader :name
    def initialize(name)
      @name = name
      super("required variable '#{name}' is not set")
    end
  end

  class UidNumberAlreadyExists < Error
    attr_reader :number
    def initialize(number)
      @number = number
      super("uid number '#{@number}' already exists")
    end
  end

  class GroupDoesNotExist < Error
    attr_reader :name
    def initialize(name)
      @name = name
      super("group '#{@name}' doesn't exist")
    end
  end

  class GidNumberAlreadyExists < Error
    attr_reader :number
    def initialize(number)
      @number = number
      super("gid number '#{@number}' already exists")
    end
  end

  class GidNumberDoesNotExist < Error
    attr_reader :number
    def initialize(number)
      @number = number
      super("gid number '#{@number}' doesn't exist")
    end
  end

  class GroupDoesNotHaveSambaSID < Error
    attr_reader :number
    def initialize(number)
      @number = number
      super("sambaSID attribute doesn't exist for gid number '#{@number}'")
    end
  end

  class CanNotChangePrimaryGroup < Error
    attr_reader :group, :members
    def initialize(group, members)
      @group = group
      @members = members
      message = "cannot change primary group from '#{group}' to other group "
      message << "due to no other belonged groups: #{members.join(', ')}"
      super(message)
    end
  end

  class PrimaryGroupCanNotBeDestroyed < Error
    attr_reader :group, :members
    def initialize(group, members)
      @group = group
      @members = members
      message = "cannot destroy group '#{group}' due to members who belong "
      message << "to the group as primary group: #{members.join(', ')}"
      super(message)
    end
  end

  class Base < ActiveLdap::Base
    class << self
      def establish_connection(config={}, reference_only=true)
        Config.init
        Config.required_variables :suffix
        default_config = {:base => Config.suffix}
        if reference_only
          Config.required_variables :reference_host, :reference_port
          default_config[:host] = Config.reference_host
          default_config[:port] = Config.reference_port
          default_config[:bind_format] = Config.reference_bind_format
          default_config[:user] = Config.reference_user
          default_config[:password] = Config.reference_password
          default_config[:method] = :tls if Config.reference_use_tls
          default_config[:allow_anonymous] = Config.reference_allow_anonymous
        else
          Config.required_variables :update_host, :update_port
          default_config[:host] = Config.update_host
          default_config[:port] = Config.update_port
          default_config[:bind_format] = Config.update_bind_format
          default_config[:user] = Config.update_user
          default_config[:password] = Config.update_password
          default_config[:method] = :tls if Config.update_use_tls
          default_config[:allow_anonymous] = Config.update_allow_anonymous
        end
        default_config.each do |key, value|
          default_config.delete(key) if value.nil?
        end
        super(default_config.merge(config))
      end

      def restart_nscd
        if system("/etc/init.d/nscd status >/dev/null 2>&1")
          system("/etc/init.d/nscd stop >/dev/null 2>&1")
          begin
            yield if block_given?
          ensure
            system("/etc/init.d/nscd start >/dev/null 2>&1")
          end
        end
      end

      private
      def extract_ldap_mapping_options(options)
        extracted_options = {}
        ActiveLdap::Base::VALID_LDAP_MAPPING_OPTIONS.each do |key|
          extracted_options[key] = options[key] if options.has_key?(key)
        end
        extracted_options
      end
    end
  end
end
