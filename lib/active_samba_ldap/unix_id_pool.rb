module ActiveSambaLdap
  class UnixIdPool < Base
    extend Unreloadable

    class << self
      def ldap_mapping(options={})
        default_options = {
          :dn_attribute => "sambaDomainName",
          :prefix => "",
          :classes => ["top", "sambaDomain", "sambaUnixIdPool"],
        }
        options = default_options.merge(options)
        super options
      end
    end
  end
end
