require 'time'
require 'fileutils'
require 'English'

module ActiveSambaLdap
  module Account
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

    FAR_FUTURE_TIME = Time.parse("2050/01/01").to_i.to_s
    ACCOUNT_FLAGS_RE = /\A\[([NDHTUMWSLXI ]+)\]\z/
    NAME_RE = /\A(?!\d)[\w @_\-\.]+\z/

    module ClassMethods
      def ldap_mapping(options={})
        default_options = {
          :dn_attribute => "uid",
          :ldap_scope => :sub,
          :primary_group_class => "Group",
          :primary_group_foreign_key => "gidNumber",
          :primary_group_primary_key => "gidNumber",
          :groups_class => "Group",
          :groups_many => "memberUid",
        }
        options = default_options.merge(options)
        super(extract_ldap_mapping_options(options))
        belongs_to :primary_group,
                   :class => options[:primary_group_class],
                   :foreign_key => options[:primary_group_foreign_key],
                   :primary_key => options[:primary_group_primary_key],
                   :extend => PrimaryGroupProxy
        belongs_to :groups,
                   :class => options[:groups_class],
                   :many => options[:groups_many]
      end

      def valid_name?(name)
        NAME_RE =~ name ? true : false
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
        Integer(configuration[:start_uid])
      end

      def start_rid
        uid2rid(start_uid)
      end

      def find_available_uid_number(pool)
        uid_number = (pool.uid_number || start_uid).to_s

        100.times do |i|
          if find(:first, :attribute => "uidNumber", :value => uid_number).nil?
            return uid_number
          end
          uid_number = uid_number.succ
        end

        nil
      end

      module PrimaryGroupProxy
        def replace(entry)
          super
          if @target
            if @target.samba_sid.to_s.empty?
              raise GroupDoesNotHaveSambaSID.new(@target.gid_number)
            end
            @owner.samba_primary_group_sid = @target.samba_sid
          else
            @owner.samba_primary_group_sid = nil
          end
          entry
        end
      end
    end

    def init(uid_number, group)
      self.cn = uid
      self.sn = uid
      self.gecos = uid
      self.home_directory = substituted_value(:user_home) {"/nonexistent"}
      self.login_shell = substituted_value(:user_login_shell) {"/bin/false"}
      self.samba_home_path = substituted_value(:user_samba_home)
      self.samba_home_drive = substituted_value(:user_home_drive)
      self.samba_profile_path = substituted_value(:user_profile)
      self.samba_logon_script = substituted_value(:user_script)
      self.samba_logon_time = "0"
      self.samba_logoff_time = FAR_FUTURE_TIME
      self.samba_kickoff_time = FAR_FUTURE_TIME
      self.samba_acct_flags = default_account_flags

      self.change_uid_number(uid_number)
      self.primary_group = group

      self.user_password = "{crypt}x"
      self.samba_lm_password = "XXX"
      self.samba_nt_password = "XXX"
      self.samba_pwd_last_set = "0"
      self.enable_password_change
      self.disable_forcing_password_change

      self.disable

      self
    end

    def destroy(options={})
      if options[:removed_from_group]
        groups.each do |group|
          remove_from_group(group)
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
      self.uid_number = Integer(uid).to_s
      change_sid(rid, allow_non_unique)
    end

    def change_uid_number_by_rid(rid, allow_non_unique=false)
      change_uid_number(self.class.rid2uid(rid), allow_non_unique)
    end

    def change_sid(rid, allow_non_unique=false)
      sid = "#{self.class.configuration[:sid]}-#{rid}"
      # check_unique_sid_number(sid) unless allow_non_unique
      self.samba_sid = sid
    end

    def rid
      Integer(samba_sid.split(/-/).last)
    end

    def change_password(password)
      hash_type = self.class.configuration[:password_hash_type]
      hashed_password = ActiveLdap::UserPassword.__send__(hash_type, password)
      self.user_password = hashed_password
    end

    def change_samba_password(password)
      self.samba_lm_password = Samba::Encrypt.lm_hash(password)
      self.samba_nt_password = Samba::Encrypt.ntlm_hash(password)
      self.samba_pwd_last_set = Time.now.to_i.to_s
    end

    def enable_password_change
      self.samba_pwd_can_change = "0"
    end

    def disable_password_change
      self.samba_pwd_can_change = FAR_FUTURE_TIME
    end

    def can_change_password?
      samba_pwd_can_change.nil? or
        Time.at(samba_pwd_can_change.to_i) <= Time.now
    end

    def enable_forcing_password_change
      self.samba_pwd_must_change = "0"
      if /X/ =~ samba_acct_flags.to_s
        self.samba_acct_flags = samba_acct_flags.sub(/X/, '')
      end
      if samba_pwd_last_set.to_i.zero?
        self.samba_pwd_last_set = FAR_FUTURE_TIME
      end
    end

    def disable_forcing_password_change
      self.samba_pwd_must_change = FAR_FUTURE_TIME
    end

    def must_change_password?
      !(/X/ =~ samba_acct_flags.to_s or
        samba_pwd_must_change.nil? or
        Time.at(samba_pwd_must_change.to_i) > Time.now)
    end

    def enable
      if /D/ =~ samba_acct_flags.to_s
        self.samba_acct_flags = samba_acct_flags.gsub(/D/, '')
      end
    end

    def disable
      flags = ""
      if ACCOUNT_FLAGS_RE =~ samba_acct_flags.to_s
        flags = $1
        return if /D/ =~ flags
      end
      self.samba_acct_flags = "[D#{flags}]"
    end

    def enabled?
      !disabled?
    end

    def disabled?
      (/D/ =~ samba_acct_flags.to_s) ? true : false
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
      config = self.class.configuration
      if block_given?
        value = config[key.to_sym]
        if value
          substitute_template(value)
        else
          yield
        end
      else
        substitute_template(config[key.to_sym])
      end
    end
  end
end
