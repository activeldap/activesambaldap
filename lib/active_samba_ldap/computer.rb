require 'active_samba_ldap/account'

module ActiveSambaLdap
  class Computer < Base
    include Account
    class << self
      def ldap_mapping(options={})
        default_options = {
          :prefix => configuration[:computers_prefix],
          :classes => ["top", "inetOrgPerson", "posixAccount",
                       "sambaSamAccount"],
        }
        super(default_options.merge(options))
      end

      def valid_name?(name)
        /\$\Z/ =~ name and User.valid_name?($PREMATCH)
      end
    end

    def remove_from_group(group)
      group.computers.delete(self)
    end

    private
    def default_account_flags
      "[W]"
    end
  end
end
