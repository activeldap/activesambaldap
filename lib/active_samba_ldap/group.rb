require 'English'

module ActiveSambaLdap
  class Group < Base
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
      def ldap_mapping(options={})
        Config.required_variables :groups_prefix
        default_options = {
          :dn_attribute => "cn",
          :prefix => Config.groups_prefix,
          :classes => ["posixGroup", "sambaGroupMapping"],

          :members_wrap => "memberUid",
          :user_members_class => "User",
          :computer_members_class => "Computer",

          :primary_members_foreign_key => "gidNumber",
          :primary_members_primary_key => "gidNumber",
          :primary_user_members_class => "User",
          :primary_computer_members_class => "Computer",
        }
        options = default_options.merge(options)
        super(extract_ldap_mapping_options(options))
        init_associations(options)
      end

      def create(name, options={})
        group = new(name)
        gid_number, pool = ensure_gid_number(options)
        group.change_gid_number(gid_number)
        group.change_type(options[:group_type] || "domain")
        group.description = options[:description] || name
        group.displayName = options[:display_name] || name
        if group.save and pool
          pool.gidNumber = Integer(group.gidNumber).succ
          pool.save!
        end
        group
      end

      def find_by_name_or_gid_number(key)
        group = nil
        begin
          gid_number = Integer(key)
          group = find_by_gid_number(gid_number)
          raise GidNumberDoesNotExist.new(gid_number) if group.nil?
        rescue ArgumentError
          group = new(key)
          raise GroupDoesNotExist.new(key) unless group.exists?
        end
        group
      end

      def find_by_gid_number(number)
        options = {:objects => true}
        attribute = "gidNumber"
        value = Integer(number).to_s
        find(:first, :filter => "(#{attribute}=#{value})")
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

      def start_gid
        ActiveSambaLdap::Config.required_variables :start_gid
        Integer(ActiveSambaLdap::Config.start_gid)
      end

      def start_rid
        gid2rid(start_gid)
      end

      def find_available_gid_number(pool)
        gid_number = pool.gidNumber || start_gid

        100.times do |i|
          if find(:first, :filter => "(gidNumber=#{gid_number})").nil?
            return gid_number
          end
          gid_number = gid_number.succ
        end

        nil
      end

      private
      def init_associations(options)
        association_options = {}
        options.each do |key, value|
          case key.to_s
          when /^((?:primary_)?(?:(?:user|computer)_)?members)_/
            association_options[$1] ||= {}
            association_options[$1][$POSTMATCH.to_sym] = value
          end
        end

        members_opts = association_options["members"] || {}
        user_members_opts = association_options["user_members"] || {}
        computer_members_opts = association_options["computer_members"] || {}
        has_many :user_members, members_opts.merge(user_members_opts)
        has_many :computer_members,
                 members_opts.merge(computer_members_opts)

        primary_members_opts = association_options["primary_members"] || {}
        primary_user_members_opts =
          association_options["primary_user_members"] || {}
        primary_computer_members_opts =
          association_options["primary_computer_members"] || {}
        has_many :primary_user_members,
                 primary_members_opts.merge(primary_user_members_opts)
        has_many :primary_computer_members,
                 primary_members_opts.merge(primary_computer_members_opts)
      end

      def ensure_gid_number(options)
        gid_number = options[:gid_number]
        pool = nil
        unless gid_number
          pool_class = options[:pool_class] || Class.new(UnixIdPool)
          samba_domain = options[:samba_domain] || Config[:samba_domain]
          pool = pool_class.find(samba_domain)
          gid_number = find_available_gid_number(pool)
        end
        [gid_number, pool]
      end
    end

    def members
      user_members.to_ary + computer_members.to_ary
    end

    def reload_members
      user_members.reload
      computer_members.reload
    end

    def primary_members
      primary_user_members.to_ary + primary_computer_members.to_ary
    end

    def reload_primary_members
      primary_user_members.reload
      primary_computer_members.reload
    end

    def change_gid_number(gid, allow_non_unique=false)
      check_unique_gid_number(gid) unless allow_non_unique
      rid = self.class.gid2rid(gid)
      self.gidNumber = gid.to_s
      change_sid(rid, allow_non_unique)
    end

    def change_gid_number_by_rid(rid, allow_non_unique=false)
      change_uid_number(self.class.rid2gid(rid), allow_non_unique)
    end

    def change_sid(rid, allow_non_unique=false)
      sid = "#{ActiveSambaLdap::Config.sid}-#{rid}"
      # check_unique_sid_number(sid) unless allow_non_unique
      self.sambaSID = sid
    end

    def rid
      Integer(sambaSID.split(/-/).last)
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
      self.sambaGroupType = type.to_s
    end

    def remove_member(member_or_uid)
      uid = ensure_uid(member_or_uid)
      new_member_uid = member_uid(true)
      unless new_member_uid.reject! {|_uid| uid == _uid}.nil?
        self.member_uid = new_member_uid
        save!
      end
    end

    def add_member(member_or_uid)
      uid = ensure_uid(member_or_uid)
      unless member_uid(true).find {|_uid| uid == _uid}
        self.member_uid = (member_uid(true) + [uid]).sort
        save!
      end
    end

    def destroy(options={})
      if options[:remove_members]
        if options[:force_change_primary_members]
          change_primary_members(options)
          reload_primary_members
        end
        pr_members = primary_members
        unless pr_members.empty?
          not_destroyed_members = pr_members.collect {|x| x.uid}
          raise PrimaryGroupCanNotBeDestroyed.new(cn, not_destroyed_members)
        end
        members.each do |member|
          remove_member(member)
        end
      end
      super()
    end

    private
    def ensure_uid(member_or_uid)
      if member_or_uid.is_a?(String)
        member_or_uid
      else
        member_or_uid.uid
      end
    end

    def check_unique_gid_number(gid_number)
      ActiveSambaLdap::Base.restart_nscd do
        if self.class.find_by_gid_number(Integer(gid_number))
          raise GidNumberAlreadyExists.new(gid_number)
        end
      end
    end

    def change_primary_members(options={})
      name = cn

      pr_members = primary_members
      cannot_removed_members = []
      pr_members.each do |member|
        if (member.groups.collect {|group| group.cn} - [name]).empty?
          cannot_removed_members << member.uid
        end
      end
      unless cannot_removed_members.empty?
        raise CanNotChangePrimaryGroup.new(name, cannot_removed_members)
      end

      pr_members.each do |member|
        new_group = member.groups.find {|gr| gr.cn != name}
        member.change_group(new_group.gidNumber)
        member.save!
      end
    end
  end
end
