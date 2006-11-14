module ActiveSambaLdap
  class Idmap < Base
    extend Unreloadable

    class << self
      def ldap_mapping(options={})
        default_options = {
          :dn_attribute => "sambaSID",
          :prefix => configuration[:idmap_prefix],
          :classes => ["top", "sambaIdmapEntry"],
        }
        options = default_options.merge(options)
        super options
      end
    end
  end
end
