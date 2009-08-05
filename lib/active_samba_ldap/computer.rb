require 'active_samba_ldap/base'
require 'active_samba_ldap/entry'
require 'active_samba_ldap/samba_entry'
require 'active_samba_ldap/account_entry'
require 'active_samba_ldap/computer_account_entry'
require 'active_samba_ldap/samba_account_entry'

module ActiveSambaLdap
  class Computer < Base
    include Reloadable

    include Entry
    include SambaEntry

    include AccountEntry
    include ComputerAccountEntry
    include SambaAccountEntry
    include SambaComputerAccountEntry

    private
    def default_account_flags
      "[W]"
    end
  end
end
