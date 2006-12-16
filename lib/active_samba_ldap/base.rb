require 'active_samba_ldap/reloadable'

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

  class RequiredVariablesAreNotSet < RequiredVariableIsNotSet
    attr_reader :names
    def initialize(names)
      @names = names
      super("required variables '#{names.join(', ')}' are not set")
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

  class InvalidConfigurationFormatError < Error
    attr_reader :file, :location, :detail
    def initialize(file, location, detail)
      @file = file
      @location = location
      @detail = detail
      super("found invalid configuration format at #{@file}:#{@location}" +
            ": #{@detail}")
    end
  end

  class InvalidConfigurationValueError < Error
    attr_reader :name, :value, :detail
    def initialize(name, value, detail)
      @name = name
      @value = value
      @detail = detail
      super("the value of #{@name} '#{@value.inspect}' is invalid: #{@detail}")
    end
  end

  class Base < ActiveLdap::Base
    include Reloadable

    class << self
      def restart_nscd
        nscd_working = system("/etc/init.d/nscd status >/dev/null 2>&1")
        system("/etc/init.d/nscd stop >/dev/null 2>&1") if nscd_working
        yield if block_given?
      ensure
        system("/etc/init.d/nscd start >/dev/null 2>&1") if nscd_working
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
