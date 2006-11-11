module ActiveSambaLdap
  class Ou < Base
    class << self
      def ldap_mapping(options={})
        default_options = {
          :dn_attribute => "ou",
          :prefix => "",
          :classes => ["top", "organizationalUnit"],
          :scope => :sub,
        }
        options = default_options.merge(options)
        super(options)
      end
    end
  end
end
