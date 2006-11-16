module ActiveSambaLdap
  module UserAccount
    NAME_RE = /\A#{Account::NAME_RE_SRC}\z/

    def self.included(base)
      super
      base.extend(ClassMethods)
      base.validates_format_of :uid, :with => NAME_RE
    end

    module ClassMethods
      def valid_name?(name)
        NAME_RE =~ name ? true : false
      end

      private
      def default_prefix
        configuration[:users_suffix]
      end
    end

    def remove_from_group(group)
      group.users.delete(self)
    end

    def default_gid_number
      self.class.configuration[:default_user_gid]
    end
  end
end
