require 'active_samba_ldap/group'

module ActiveSambaLdap
  class SambaGroup < Group
    include Reloadable::Subclasses

    # from librpc/ndr/security.h in Samba
    SID_BUILTIN = "S-1-5-32"

    # from source/include/rpc_misc.c in Samba
    DOMAIN_ADMINS_RID = 0x00000200
    DOMAIN_USERS_RID = 0x00000201
    DOMAIN_GUESTS_RID = 0x00000202
    DOMAIN_COMPUTERS_RID = 0x00000203

    LOCAL_ADMINS_RID = 0x00000220
    LOCAL_USERS_RID = 0x00000221
    LOCAL_GUESTS_RID = 0x00000222
    LOCAL_POWER_USERS_RID = 0x00000223

    LOCAL_ACCOUNT_OPERATORS_RID = 0x00000224
    LOCAL_SYSTEM_OPERATORS_RID = 0x00000225
    LOCAL_PRINT_OPERATORS_RID = 0x00000226
    LOCAL_BACKUP_OPERATORS_RID = 0x00000227

    LOCAL_REPLICATORS_RID = 0x00000228


    # from source/rpc_server/srv_util.c in Samba
    DOMAIN_ADMINS_NAME = "Domain Administrators"
    DOMAIN_USERS_NAME = "Domain Users"
    DOMAIN_GUESTS_NAME = "Domain Guests"
    DOMAIN_COMPUTERS_NAME = "Domain Computers"


    WELL_KNOWN_RIDS = []
    WELL_KNOWN_NAMES = []
    constants.each do |name|
      case name
      when /_RID$/
        WELL_KNOWN_RIDS << const_get(name)
      when /_NAME$/
        WELL_KNOWN_NAMES << const_get(name)
      end
    end


    # from source/librpc/idl/lsa.idl in Samba
    TYPES = {
      "domain" => 2,
      "local" => 4,
      "builtin" => 5,
    }

    class << self
      def gid2rid(gid)
        gid = Integer(gid)
        if WELL_KNOWN_RIDS.include?(gid)
          gid
        else
          2 * gid + 1001
        end
      end

      def rid2gid(rid)
        rid = Integer(rid)
        if WELL_KNOWN_RIDS.include?(rid)
          rid
        else
          (rid - 1001) / 2
        end
      end

      def start_rid
        gid2rid(start_gid)
      end

      private
      def default_classes
        super + ["sambaGroupMapping"]
      end
    end

    def fill_default_values(options={})
      change_type(options[:group_type] || "domain") unless samba_group_type
      super
    end

    def change_gid_number(gid, allow_non_unique=false)
      super
      rid = self.class.gid2rid(gid_number.to_s)
      change_sid(rid, allow_non_unique)
    end

    def change_gid_number_by_rid(rid, allow_non_unique=false)
      change_gid_number(self.class.rid2gid(rid), allow_non_unique)
    end

    def change_sid(rid, allow_non_unique=false)
      if (LOCAL_ADMINS_RID..LOCAL_REPLICATORS_RID).include?(rid.to_i)
        sid = "#{SID_BUILTIN}-#{rid}"
      else
        sid = "#{self.class.configuration[:sid]}-#{rid}"
      end
      # check_unique_sid_number(sid) unless allow_non_unique
      self.samba_sid = sid
    end

    def rid
      Integer(samba_sid.split(/-/).last)
    end

    def change_type(type)
      normalized_type = type.to_s.downcase
      if TYPES.has_key?(normalized_type)
        type = TYPES[normalized_type]
      elsif TYPES.values.include?(type.to_i)
	# pass
      else
        raise ArgumentError, "invalid type: #{type}"
      end
      self.samba_group_type = type.to_s
    end
  end
end
