require 'active_samba_ldap/account'

module ActiveSambaLdap
  class Computer < Base
    include Account
    class << self
      def ldap_mapping(options={})
        Config.required_variables :computers_prefix
        default_options = {
          :dnattr => "uid",
          :prefix => Config.computers_prefix,
          :classes => ["top", "inetOrgPerson", "posixAccount",
                       "sambaSamAccount"],
          :group_class_name => "Group",
          :group_foreign_key => "memberUid",
        }
        options = default_options.merge(options)
        super options
        belongs_to :groups,
                   :class_name => options[:group_class_name],
                   :foreign_key => options[:group_foreign_key]
        self.group_class_name = options[:group_class_name]
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
