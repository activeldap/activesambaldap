require 'active_samba_ldap/account'
require 'active_samba_ldap/user_account'
require 'active_samba_ldap/samba_account'

module ActiveSambaLdap
  class SambaComputer < Base
    include Account
    include ComputerAccount
    include SambaAccount

    private
    def default_account_flags
      "[W]"
    end
  end
end
