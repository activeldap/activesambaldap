require 'active_samba_ldap/account'

module ActiveSambaLdap
  class User < Base
    include Account

    class << self
      def ldap_mapping(options={})
        Config.required_variables :users_prefix, :sid
        default_options = {
          :dnattr => "uid",
          :prefix => Config.users_prefix,
          :classes => ["top", "inetOrgPerson", "posixAccount",
                       "shadowAccount", "sambaSamAccount"],
          :group_class_name =>  "Group",
          :group_foreign_key => "memberUid"
        }
        options = default_options.merge(options)
        super(options)
        belongs_to :groups,
                   :class_name => options[:group_class_name],
                   :foreign_key => options[:group_foreign_key]
        self.group_class_name = options[:group_class_name]
      end
    end

    private
    def default_account_flags
      "[UH]"
    end
  end
end
