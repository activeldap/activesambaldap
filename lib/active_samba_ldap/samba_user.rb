require 'active_samba_ldap/entry'
require 'active_samba_ldap/account'
require 'active_samba_ldap/user_account'
require 'active_samba_ldap/samba_account'

module ActiveSambaLdap
  class SambaUser < Base
    include Reloadable::Subclasses

    include Entry

    include Account
    include UserAccount
    include SambaAccount

    def fill_default_values(options={})
      super

      subst = Proc.new do |key|
        value = options[key]
        if value
          substitute_template(value)
        else
          substituted_value(key)
        end
      end

      self.samba_home_path ||= subst[:user_home_unc]
      self.samba_home_drive ||= subst[:user_home_drive].sub(/([^:])$/, "\\1:")
      self.samba_profile_path ||= subst[:user_profile]
      self.samba_logon_script ||= subst[:user_logon_script]
    end

    private
    def default_account_flags
      "[UH]"
    end
  end
end
