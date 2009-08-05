require 'active_samba_ldap/reloadable'

module ActiveSambaLdap
  class Error < StandardError
    include ActiveSambaLdap::GetTextSupport
  end

  class MissingRequiredVariableError < Error
    attr_reader :names
    def initialize(names)
      names = names.to_a
      @names = names
      super(n_("required variable is not set: %s",
               "required variables are not set: %s",
               names.size) % names.join(', '))
    end

    def name
      @names.first
    end
  end

  class UidNumberAlreadyExists < Error
    attr_reader :number
    def initialize(number)
      @number = number
      super(_("uid number already exists: %s") % number)
    end
  end

  class GroupDoesNotExist < Error
    attr_reader :name
    def initialize(name)
      @name = name
      super(_("group doesn't exist: %s") % name)
    end
  end

  class GidNumberAlreadyExists < Error
    attr_reader :number
    def initialize(number)
      @number = number
      super(_("gid number already exists: %s") % number)
    end
  end

  class GidNumberDoesNotExist < Error
    attr_reader :number
    def initialize(number)
      @number = number
      super(_("gid number doesn't exist: %s") % number)
    end
  end

  class GroupDoesNotHaveSambaSID < Error
    attr_reader :number
    def initialize(number)
      @number = number
      super(_("sambaSID attribute doesn't exist for gid number '%s'") % number)
    end
  end

  class CanNotChangePrimaryGroup < Error
    attr_reader :group, :members
    def initialize(group, members)
      @group = group
      @members = members
      format = _("cannot change primary group from '%s' to other group " \
                 "due to no other belonged groups: %s")
      super(format % [group, members.join(', ')])
    end
  end

  class PrimaryGroupCanNotBeDestroyed < Error
    attr_reader :group, :members
    def initialize(group, members)
      @group = group
      @members = members
      format = _("cannot destroy group '%s' due to members who belong " \
                 "to the group as primary group: %s")
      super(format % [group, members.join(', ')])
    end
  end

  class InvalidConfigurationFormatError < Error
    attr_reader :file, :location, :detail
    def initialize(file, location, detail)
      @file = file
      @location = location
      @detail = detail
      format = _("found invalid configuration format at %s:%s: %s")
      super(format % [file, location, detail])
    end
  end

  class InvalidConfigurationValueError < Error
    attr_reader :name, :value, :detail
    def initialize(name, value, detail)
      @name = name
      @value = value
      @detail = detail
      format = _("the value of %s '%s' is invalid: %s")
      super(format % [name, value.inspect, detail])
    end
  end

  class NotSambaAavialableError < Error
    attr_reader :object
    def initialize(object)
      @object = object
      super(_("%s is not Samba available") % [object.inspect])
    end
  end

  class NotUnixAavialableError < Error
    attr_reader :object
    def initialize(object)
      @object = object
      super(_("%s is not UNIX available") % [object.inspect])
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
