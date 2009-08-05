module ActiveSambaLdap
  module SambaComputerAccountEntry
    def self.included(base)
      super
      base.extend(ClassMethods)
    end

    module ClassMethods
      def samba_object_classes
        if configuration[:samba4]
          super + ["computer"]
        else
          super
        end
      end
    end
  end
end
