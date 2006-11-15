module ActiveSambaLdap
  class Dc < Base
    include Reloadable::Subclasses

    class << self
      def ldap_mapping(options={})
        default_options = {
          :dn_attribute => "dc",
          :prefix => "",
          :classes => ["top", "dcObject", "organization"],
        }
        options = default_options.merge(options)
        super(options)
      end
    end
  end
end
