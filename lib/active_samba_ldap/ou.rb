module ActiveSambaLdap
  class Ou < Base
    class << self
      def ldap_mapping(options={})
        default_options = {
          :dnattr => "ou",
          :prefix => "",
          :classes => ["top", "organizationalUnit"],
        }
        options = default_options.merge(options)
        super(options)
      end

      def ldap_scope
        LDAP::LDAP_SCOPE_SUBTREE
      end
    end
  end
end
