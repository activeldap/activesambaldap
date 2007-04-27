require 'active_samba_ldap/base'
require 'active_samba_ldap/entry'
require 'active_samba_ldap/samba_entry'
require 'active_samba_ldap/group_entry'
require 'active_samba_ldap/samba_group_entry'

module ActiveSambaLdap
  class Group < Base
    include Reloadable

    include Entry
    include SambaEntry

    include GroupEntry
    include SambaGroupEntry
  end
end
