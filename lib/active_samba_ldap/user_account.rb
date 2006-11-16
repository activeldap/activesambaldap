module ActiveSambaLdap
  module UserAccount
    def self.included(base)
      super
      base.extend(ClassMethods)
    end

    module ClassMethods
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
