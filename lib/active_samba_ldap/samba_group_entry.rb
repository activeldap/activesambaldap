require 'active_samba_ldap/samba_entry'

module ActiveSambaLdap
  module SambaGroupEntry
    include SambaEntry

    def self.included(base)
      super
      base.extend(ClassMethods)
    end

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

    module ClassMethods
      def samba_object_classes
        if samba4?
          ["group"]
        else
          ["sambaGroupMapping"]
        end
      end

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
    end

    def fill_default_values(options={})
      if samba_available?
        options = options.stringify_keys
        change_type(options["group_type"] || "domain") unless samba_group_type
        self.display_name ||= options["display_name"] || cn
      end
      super
    end

    def change_gid_number(gid, allow_non_unique=false)
      result = super
      return result unless samba_available?
      rid = self.class.gid2rid(gid_number)
      change_sid(rid, allow_non_unique)
    end

    def change_gid_number_by_rid(rid, allow_non_unique=false)
      assert_samba_available
      change_gid_number(self.class.rid2gid(rid), allow_non_unique)
    end

    def change_sid(rid, allow_non_unique=false)
      assert_samba_available
      if (LOCAL_ADMINS_RID..LOCAL_REPLICATORS_RID).include?(rid.to_i)
        sid = "#{SID_BUILTIN}-#{rid}"
      else
        sid = "#{self.class.configuration[:sid]}-#{rid}"
      end
      # check_unique_sid_number(sid) unless allow_non_unique
      self.samba_sid = sid
    end

    def rid
      assert_samba_available
      Integer(samba_sid.split(/-/).last)
    end

    def change_type(type)
      assert_samba_available
      normalized_type = type.to_s.downcase
      if samba4?
        self.group_type = ActiveDirectory::GroupType.resolve(normalized_type)
      else
        if TYPES.has_key?(normalized_type)
          type = TYPES[normalized_type]
        elsif TYPES.values.include?(type.to_i)
          # pass
        else
          # TODO: add available values
          raise ArgumentError, _("invalid type: %s") % type
        end
        self.samba_group_type = type.to_s
      end
    end

    def set_object_category
      _base = ActiveSambaLdap.base
      self.object_category = "cn=Group,cn=Schema,cn=Configuration,#{_base}"
    end
  end
end
