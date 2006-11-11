require 'active_samba_ldap/account'

module ActiveSambaLdap
  class Computer < Base
    include Account
    class << self
      def ldap_mapping(options={})
        Config.required_variables :computers_prefix
        default_options = {
          :dn_attribute => "uid",
          :ldap_scope => :sub,
          :prefix => Config.computers_prefix,
          :classes => ["top", "inetOrgPerson", "posixAccount",
                       "sambaSamAccount"],
          :group_class => "Group",
          :groups_many => "memberUid",
        }
        options = default_options.merge(options)
        super(extract_ldap_mapping_options(options))
        belongs_to :groups,
                   :class => options[:group_class],
                   :many => options[:groups_many]
        self.group_class_name = options[:group_class]
      end

      def valid_name?(name)
        /\$\Z/ =~ name and User.valid_name?($PREMATCH)
      end
    end

    private
    def default_account_flags
      "[W]"
    end
  end
end
