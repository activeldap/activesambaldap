module ActiveSambaLdap
  class Idmap < Base
    class << self
      def ldap_mapping(options={})
        Config.required_variables :idmap_prefix
        default_options = {
          :dnattr => "sambaSID",
          :prefix => Config.idmap_prefix,
          :classes => ["top", "sambaIdmapEntry"],
        }
        options = default_options.merge(options)
        super options
      end
    end
  end
end
