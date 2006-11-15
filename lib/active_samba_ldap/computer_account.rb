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
  end
end
