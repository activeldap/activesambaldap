require 'active_samba_ldap/account'
require 'active_samba_ldap/computer_account'

module ActiveSambaLdap
  class Computer < Base
    include Reloadable::Subclasses

    include Entry

    include Account
    include ComputerAccount
  end
end
