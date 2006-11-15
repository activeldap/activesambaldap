require 'active_samba_ldap/account'
require 'active_samba_ldap/user_account'
require 'active_samba_ldap/samba_account'

module ActiveSambaLdap
  class SambaUser < Base
    include Account
    include UserAccount
    include SambaAccount

    private
    def default_account_flags
      "[UH]"
    end
  end
end
