require 'active_samba_ldap/account'

module ActiveSambaLdap
  class User < Base
    include Account

    class << self
      def ldap_mapping(options={})
        Config.required_variables :users_prefix, :sid
        default_options = {
          :prefix => Config.users_prefix,
          :classes => ["top", "inetOrgPerson", "posixAccount",
                       "sambaSamAccount"],
        }
        super(default_options.merge(options))
      end
    end

    def remove_from_group(group)
      group.users.delete(self)
    end

    private
    def default_account_flags
      "[UH]"
    end
  end
end
