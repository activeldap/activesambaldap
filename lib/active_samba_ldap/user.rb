require 'active_samba_ldap/entry'
require 'active_samba_ldap/account'
require 'active_samba_ldap/user_account'

module ActiveSambaLdap
  class User < Base
    include Reloadable::Subclasses

    include Entry

    include Account
    include UserAccount
  end
end
