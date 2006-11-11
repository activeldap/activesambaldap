require 'active_samba_ldap/account'

module ActiveSambaLdap
  class User < Base
    include Account

    class << self
      def ldap_mapping(options={})
        Config.required_variables :users_prefix, :sid
        default_options = {
          :dn_attribute => "uid",
          :ldap_scope => :sub,
          :prefix => Config.users_prefix,
          :classes => ["top", "inetOrgPerson", "posixAccount",
                       "shadowAccount", "sambaSamAccount"],
          :group_class =>  "Group",
          :groups_many => "memberUid"
        }
        options = default_options.merge(options)
        super(extract_ldap_mapping_options(options))
        belongs_to :groups,
                   :class => options[:group_class],
                   :many => options[:groups_many]
        self.group_class_name = options[:group_class]
      end
    end

    private
    def default_account_flags
      "[UH]"
    end
  end
end
