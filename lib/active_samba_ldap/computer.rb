require 'active_samba_ldap/base'
require 'active_samba_ldap/entry'
require 'active_samba_ldap/samba_entry'
require 'active_samba_ldap/account'
require 'active_samba_ldap/computer_account'
require 'active_samba_ldap/samba_account'

module ActiveSambaLdap
  class Computer < Base
    include Reloadable

    include Entry
    include SambaEntry

    include Account
    include ComputerAccount
    include SambaAccount

    private
    def default_account_flags
      "[W]"
    end
  end
end
