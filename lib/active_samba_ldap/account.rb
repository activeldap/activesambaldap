require 'time'
require 'fileutils'
require 'English'

module ActiveSambaLdap
  module Account
    def self.included(base)
      super
      base.extend(ClassMethods)
      base.class_eval(<<-EOC, __FILE__, __LINE__ + 1)
        cattr_accessor :group_class_name
        cattr_writer :group_class
        def self.group_class
          @@group_class || super
        end
      EOC
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

    FAR_FUTURE_TIME = Time.parse("2050/01/01").to_i.to_s
    ACCOUNT_FLAGS_RE = /\A\[([NDHTUMWSLXI ]+)\]\z/
    NAME_RE = /\A(?!\d)[\w @_\-\.]+\z/

    module ClassMethods
      def valid_name?(name)
        NAME_RE =~ name ? true : false
      end

      def group_class
        group_class_name.split(/::/).inject(self) do |ret, name|
          ret.const_get(name)
        end
      end

      def find_by_uid_number(number)
        options = {:objects => true}
        attribute = "uidNumber"
        value = Integer(number)
        find(:first, :filter => "(#{attribute}=#{value})")
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

      def start_uid
        ActiveSambaLdap::Config.required_variables :start_uid
        Integer(ActiveSambaLdap::Config.start_uid)
      end

      def start_rid
        uid2rid(start_uid)
      end

      def find_available_uid_number(pool)
        uid_number = (pool.uidNumber || start_uid).to_s

        100.times do |i|
          if find(:first, :attribute => "uidNumber", :value => uid_number).nil?
            return uid_number
          end
          uid_number = uid_number.succ
        end

        nil
      end
    end

    def init(uid_number, gid_number)
      self.cn = uid
      self.sn = uid
      self.gecos = uid
      self.homeDirectory = substituted_value(:user_home) {"/nonexistent"}
      self.loginShell = substituted_value(:user_login_shell) {"/bin/false"}
      self.sambaHomePath = substituted_value(:user_samba_home)
      self.sambaHomeDrive = substituted_value(:user_home_drive)
      self.sambaProfilePath = substituted_value(:user_profile)
      self.sambaLogonScript = substituted_value(:user_script)
      self.sambaLogonTime = "0"
      self.sambaLogoffTime = FAR_FUTURE_TIME
      self.sambaKickoffTime = FAR_FUTURE_TIME
      self.sambaAcctFlags = default_account_flags

      self.change_uid_number(uid_number)
      group = self.change_group(gid_number)

      self.userPassword = "{crypt}x"
      self.sambaLMPassword = "XXX"
      self.sambaNTPassword = "XXX"
      self.sambaPwdLastSet = "0"
      self.enable_password_change
      self.disable_forcing_password_change

      self.disable

      group
    end

    def destroy(options={})
      if options[:removed_from_group]
        groups.each do |group|
          group.remove_member(self)
        end
      end
      dir = home_directory
      need_remove_home_directory =
        options[:remove_home_directory] && !new_entry?
      super()
      if need_remove_home_directory and File.directory?(dir)
        if options[:remove_home_directory_interactive]
          system("rm", "-r", "-i", dir)
        else
          FileUtils.rm_r(dir)
        end
      end
      new_entry?
    end

    def change_uid_number(uid, allow_non_unique=false)
      check_unique_uid_number(uid) unless allow_non_unique
      rid = self.class.uid2rid(uid)
      self.uidNumber = Integer(uid).to_s
      change_sid(rid, allow_non_unique)
    end

    def change_uid_number_by_rid(rid, allow_non_unique=false)
      change_uid_number(self.class.rid2uid(rid), allow_non_unique)
    end

    def change_sid(rid, allow_non_unique=false)
      sid = "#{ActiveSambaLdap::Config.sid}-#{rid}"
      # check_unique_sid_number(sid) unless allow_non_unique
      self.sambaSID = sid
    end

    def rid
      Integer(sambaSID.split(/-/).last)
    end

    def change_group(gid)
      if self.class.group_class === gid
        group = gid
      else
        group = self.class.group_class.find_by_name_or_gid_number(gid)
      end
      gid_number = group.gid_number
      samba_sid = group.samba_sid
      if samba_sid.nil? or samba_sid.empty?
        raise GroupDoesNotHaveSambaSID.new(gid_number)
      end
      if gid_number
        old_gid = gid_number
        old_group = self.class.group_class.find_by_name_or_gid_number(old_gid)
        old_group.remove_member(self)
      end
      self.gid_number = gid_number
      self.samba_primary_group_sid = samba_sid
      group
    end

    def change_password(password)
      self.userPassword = ActiveLdap::UserPassword.ssha(password)
    end

    def change_samba_password(password)
      self.sambaLMPassword = Samba::Encrypt.lm_hash(password)
      self.sambaNTPassword = Samba::Encrypt.ntlm_hash(password)
      self.sambaPwdLastSet = Time.now.to_i.to_s
    end

    def enable_password_change
      self.sambaPwdCanChange = "0"
    end

    def disable_password_change
      self.sambaPwdCanChange = FAR_FUTURE_TIME
    end

    def can_change_password?
      sambaPwdCanChange.nil? or Time.at(sambaPwdCanChange.to_i) <= Time.now
    end

    def enable_forcing_password_change
      self.sambaPwdMustChange = "0"
      if /X/ =~ sambaAcctFlags.to_s
        self.sambaAcctFlags = sambaAcctFlags.sub(/X/, '')
      end
      if sambaPwdLastSet.to_i.zero?
        self.sambaPwdLastSet = FAR_FUTURE_TIME
      end
    end

    def disable_forcing_password_change
      self.sambaPwdMustChange = FAR_FUTURE_TIME
    end

    def must_change_password?
      !(/X/ =~ sambaAcctFlags.to_s or
        sambaPwdMustChange.nil? or
        Time.at(sambaPwdMustChange.to_i) > Time.now)
    end

    def enable
      if /D/ =~ sambaAcctFlags.to_s
        self.sambaAcctFlags = sambaAcctFlags.gsub(/D/, '')
      end
    end

    def disable
      flags = ""
      if ACCOUNT_FLAGS_RE =~ sambaAcctFlags.to_s
        flags = $1
        return if /D/ =~ flags
      end
      self.sambaAcctFlags = "[D#{flags}]"
    end

    def enabled?
      !disabled?
    end

    def disabled?
      (/D/ =~ sambaAcctFlags.to_s) ? true : false
    end

    private
    def check_unique_uid_number(uid_number)
      ActiveSambaLdap::Base.restart_nscd do
        if self.class.find_by_uid_number(uid_number)
          raise UidNumberAlreadyExists.new(uid_number)
        end
      end
    end

    def substitute_template(template)
      template.gsub(/%U/, uid)
    end

    def substituted_value(key)
      if block_given?
        value = ActiveSambaLdap::Config.__send__(key)
        if value
          substitute_template(value)
        else
          yield
        end
      else
        ActiveSambaLdap::Config.required_variables key
        substitute_template(ActiveSambaLdap::Config.__send__(key))
      end
    end
  end
end
