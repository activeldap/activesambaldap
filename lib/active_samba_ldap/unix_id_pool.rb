require 'active_samba_ldap/base'

module ActiveSambaLdap
  class UnixIdPool < Base
    include Reloadable

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

    def find_available_uid_number(account_class)
      find_available_number(account_class, "uidNumber", uid_number) do
        account_class.configuration[:start_uid]
      end
    end

    def find_available_gid_number(group_class)
      find_available_number(group_class, "gidNumber", gid_number) do
        group_class.configuration[:start_gid]
      end
    end

    private
    def find_available_number(klass, key, start_value)
      number = Integer(start_value || yield)

      100.times do |i|
        return number if klass.search(:filter => "(#{key}=#{number})").empty?
        number += 1
      end

      nil
    end
  end
end
