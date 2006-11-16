module ActiveSambaLdap
  module ComputerAccount
    def self.included(base)
      super
      base.extend(ClassMethods)
    end

    module ClassMethods
      def valid_name?(name)
        /\$\Z/ =~ name and super($PREMATCH)
      end

      private
      def default_prefix
        configuration[:computers_suffix]
      end
    end

    def remove_from_group(group)
      group.computers.delete(self)
    end

    def default_gid_number
      self.class.configuration[:default_computer_gid]
    end

    def created_group_name
      super.sub(/\$$/, '')
    end
  end
end
