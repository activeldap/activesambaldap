module ActiveSambaLdap
  module SambaAccountEntry
    def self.included(base)
      super
      base.extend(ClassMethods)
    end

    # from source/include/rpc_misc.c in Samba
    DOMAIN_ADMIN_RID = 0x000001F4
    DOMAIN_GUEST_RID = 0x000001F5

    # from source/rpc_server/srv_util.c in Samba
    DOMAIN_ADMIN_NAME = "Administrator"
    DOMAIN_GUEST_NAME = "Guest"

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

    # FAR_FUTURE_TIME = Time.parse("2050/01/01").to_i.to_s
    FAR_FUTURE_TIME = Time.parse("2038/01/18").to_i.to_s
    ACCOUNT_FLAGS_RE = /\A\[([NDHTUMWSLXI ]+)\]\z/

    module ClassMethods
      def samba_object_classes
        if configuration[:samba4]
          ["person", "organizationalPerson", "user"]
        else
          ["sambaSamAccount"]
        end
      end

      def uid2rid(uid)
        uid = Integer(uid)
        if WELL_KNOWN_RIDS.include?(uid)
          uid
        else
          2 * uid + 1000
        end
      end

      def rid2uid(rid)
        rid = Integer(rid)
        if WELL_KNOWN_RIDS.include?(rid)
          rid
        else
          (Integer(rid) - 1000) / 2
        end
      end

      def start_rid
        uid2rid(start_uid)
      end

      private
      def primary_group_options(options)
        super.merge(:extend => PrimaryGroupProxy)
      end

      module PrimaryGroupProxy
        def replace(entry)
          result = super
          return result unless @owner.samba_available?

          if @target and @target.samba_available?
            if @target.samba_sid.to_s.empty?
              raise GroupDoesNotHaveSambaSID.new(@target.gid_number)
            end
            @owner.samba_primary_group_sid = @target.samba_sid
          else
            @owner.samba_primary_group_sid = nil
          end

          result
        end
      end
    end

    def fill_default_values(options={})
      result = super
      return result unless samba_available?

      self.samba_logon_time ||= "0"
      self.samba_logoff_time ||= FAR_FUTURE_TIME
      self.samba_kickoff_time ||= nil

      password = options["password"]
      change_samba_password(password) if password
      self.samba_lm_password ||= "XXX"
      self.samba_nt_password ||= "XXX"
      self.samba_pwd_last_set ||= "0"

      account_flags_is_not_set = samba_acct_flags.nil?
      self.samba_acct_flags ||= default_account_flags

      can_change_password = options["can_change_password"]
      if can_change_password
        self.enable_password_change
      elsif account_flags_is_not_set or can_change_password == false
        self.disable_password_change
      end

      must_change_password = options["must_change_password"]
      if must_change_password
        self.enable_forcing_password_change
      elsif account_flags_is_not_set or must_change_password == false
        self.disable_forcing_password_change
      end

      enable_account = options["enable"]
      if enable_account
        self.enable
      elsif account_flags_is_not_set or enable_account == false
        self.disable
      end

      self
    end

    def change_uid_number(uid, allow_non_unique=false)
      result = super
      return result unless samba_available?

      rid = self.class.uid2rid(uid_number.to_s)
      change_sid(rid, allow_non_unique)
    end

    def change_uid_number_by_rid(rid, allow_non_unique=false)
      assert_samba_available
      change_uid_number(self.class.rid2uid(rid), allow_non_unique)
    end

    def change_sid(rid, allow_non_unique=false)
      assert_samba_available
      sid = "#{self.class.configuration[:sid]}-#{rid}"
      # check_unique_sid_number(sid) unless allow_non_unique
      self.samba_sid = sid
    end

    def rid
      assert_samba_available
      Integer(samba_sid.split(/-/).last)
    end

    def change_samba_password(password)
      assert_samba_available
      self.samba_lm_password = Samba::Encrypt.lm_hash(password)
      self.samba_nt_password = Samba::Encrypt.ntlm_hash(password)
      self.samba_pwd_last_set = Time.now.to_i.to_s
    end

    def enable_password_change
      assert_samba_available
      self.samba_pwd_can_change = "0"
    end

    def disable_password_change
      assert_samba_available
      self.samba_pwd_can_change = FAR_FUTURE_TIME
    end

    def can_change_password?
      assert_samba_available
      samba_pwd_can_change.nil? or
        Time.at(samba_pwd_can_change.to_i) <= Time.now
    end

    def enable_forcing_password_change
      assert_samba_available
      self.samba_pwd_must_change = "0"
      if /X/ =~ samba_acct_flags.to_s
        self.samba_acct_flags = samba_acct_flags.sub(/X/, '')
      end
      if samba_pwd_last_set.to_i.zero?
        self.samba_pwd_last_set = FAR_FUTURE_TIME
      end
    end

    def disable_forcing_password_change
      assert_samba_available
      self.samba_pwd_must_change = FAR_FUTURE_TIME
    end

    def must_change_password?
      assert_samba_available
      !(/X/ =~ samba_acct_flags.to_s or
        samba_pwd_must_change.nil? or
        Time.at(samba_pwd_must_change.to_i) > Time.now)
    end

    def enable
      assert_samba_available
      if /D/ =~ samba_acct_flags.to_s
        self.samba_acct_flags = samba_acct_flags.gsub(/D/, '')
      end
    end

    def disable
      assert_samba_available
      flags = ""
      if ACCOUNT_FLAGS_RE =~ samba_acct_flags.to_s
        flags = $1
        return if /D/ =~ flags
      end
      self.samba_acct_flags = "[D#{flags}]"
    end

    def enabled?
      assert_samba_available
      !disabled?
    end

    def disabled?
      assert_samba_available
      (/D/ =~ samba_acct_flags.to_s) ? true : false
    end
  end
end
