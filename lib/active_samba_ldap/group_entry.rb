require 'English'

require 'active_samba_ldap/entry'

module ActiveSambaLdap
  module GroupEntry
    def self.included(base)
      super
      base.extend(ClassMethods)
    end

    module ClassMethods
      def ldap_mapping(options={})
        options = default_options.merge(options)
        super(extract_ldap_mapping_options(options))
        init_associations(options)
      end

      def find_by_name_or_gid_number(key)
        group = nil
        begin
          gid_number = Integer(key)
          group = find_by_gid_number(gid_number)
          raise GidNumberDoesNotExist.new(gid_number) if group.nil?
        rescue ArgumentError
          raise GroupDoesNotExist.new(key) unless exists?(key)
          group = find(key)
        end
        group
      end

      def find_by_gid_number(number)
        attribute = "gidNumber"
        value = Integer(number).to_s
        find(:first, :filter => "(#{attribute}=#{value})")
      end

      private
      def default_options
        {
          :dn_attribute => "cn",
          :prefix => configuration[:groups_suffix],
          :classes => default_classes,
          :recommended_classes => default_recommended_classes,

          :members_wrap => "memberUid",
          :users_class => default_user_class,
          :computers_class => default_computer_class,

          :primary_members_foreign_key => "gidNumber",
          :primary_members_primary_key => "gidNumber",
          :primary_users_class => default_user_class,
          :primary_computers_class => default_computer_class,
        }
      end

      def default_classes
        ["top", "posixGroup"]
      end

      def default_recommended_classes
        []
      end

      def default_user_class
        "User"
      end

      def default_computer_class
        "Computer"
      end

      def init_associations(options)
        association_options = {}
        options.each do |key, value|
          case key.to_s
          when /^((?:primary_)?(?:(?:user|computer|member)s))_/
            association_options[$1] ||= {}
            association_options[$1][$POSTMATCH.to_sym] = value
          end
        end

        members_opts = association_options["members"] || {}
        user_members_opts = association_options["users"] || {}
        computer_members_opts = association_options["computers"] || {}
        has_many :users, members_opts.merge(user_members_opts)
        has_many :computers, members_opts.merge(computer_members_opts)

        primary_members_opts = association_options["primary_members"] || {}
        primary_user_members_opts =
          association_options["primary_users"] || {}
        primary_computer_members_opts =
          association_options["primary_computers"] || {}
        has_many :primary_users,
                 primary_members_opts.merge(primary_user_members_opts)
        has_many :primary_computers,
                 primary_members_opts.merge(primary_computer_members_opts)
      end

      def prepare_create_options(group, options)
        prepare_create_options_for_number("gid_number", group, options)
      end
    end

    def fill_default_values(options={})
      options = options.stringify_keys
      gid_number = options["gid_number"]
      change_gid_number(gid_number) if gid_number
      self.description ||= options["description"] || cn
    end

    def members
      users.to_ary + computers.to_ary
    end

    def reload_members
      users.reload
      computers.reload
    end

    def primary_members
      primary_users.to_ary + primary_computers.to_ary
    end

    def reload_primary_members
      primary_users.reload
      primary_computers.reload
    end

    def change_gid_number(gid, allow_non_unique=false)
      check_unique_gid_number(gid) unless allow_non_unique
      self.gid_number = gid.to_s
    end

    def destroy(options={})
      if options[:remove_members]
        if options[:force_change_primary_members]
          change_primary_members(options)
        end
        reload_primary_members
        unless primary_members.empty?
          not_destroyed_members = primary_members.collect {|x| x.uid}
          raise PrimaryGroupCanNotBeDestroyed.new(cn, not_destroyed_members)
        end
        self.users = []
        self.computers = []
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
        member.primary_group = new_group
        member.save!
      end
    end
  end
end
