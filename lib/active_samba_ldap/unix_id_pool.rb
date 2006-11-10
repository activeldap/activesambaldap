module ActiveSambaLdap
  class UnixIdPool < Base
    class << self
      def ldap_mapping(options={})
        default_options = {
          :dnattr => "sambaDomainName",
          :prefix => "",
          :classes => ["top", "sambaDomain", "sambaUnixIdPool"],
        }
        options = default_options.merge(options)
        super options
      end
    end
  end
end
