module ActiveSambaLdap
  module Populate
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def populate(options={})
        Private.new(self, options).populate
      end

      class Private
        def initialize(base, options)
          @base = base
          @options = options.dup
        end

        def populate
          init_classes
          init_options

          entries = []
          entries.concat(ensure_base)
          entries.concat(ensure_group_base)
          entries.concat(ensure_user_base)
          entries.concat(ensure_computer_base)
          entries.concat(ensure_idmap_base)
          entries.concat(make_groups)
          entries.concat(make_users)
          entries.concat(make_pool)

          [entries, @options]
        end

        def init_classes
          @options[:user_class] = user_class = Class.new(User)
          @options[:group_class] = group_class = Class.new(Group)
          @options[:computer_class] = computer_class = Class.new(Computer)
          @options[:idmap_class] = idmap_class = Class.new(Idmap)
          @options[:unix_id_pool_class] = id_pool_class = Class.new(UnixIdPool)

          user_class.ldap_mapping
          group_class.ldap_mapping
          computer_class.ldap_mapping
          idmap_class.ldap_mapping
          id_pool_class.ldap_mapping

          user_class.set_associated_class(:primary_group, group_class)
          computer_class.set_associated_class(:primary_group, group_class)
          user_class.set_associated_class(:groups, group_class)
          computer_class.set_associated_class(:groups, group_class)

          group_class.set_associated_class(:users, user_class)
          group_class.set_associated_class(:computers, computer_class)
          group_class.set_associated_class(:primary_users, user_class)
          group_class.set_associated_class(:primary_computers, computer_class)
        end

        def init_options
          config = @base.configuration
          @options[:start_uid] ||= Integer(config[:start_uid])
          @options[:start_gid] ||= Integer(config[:start_gid])
          @options[:administrator] ||= User::DOMAIN_ADMIN_NAME
          @options[:administrator_uid] ||= User.rid2uid(User::DOMAIN_ADMIN_RID)
          @options[:administrator_gid] ||=
            Group.rid2gid(Group::DOMAIN_ADMINS_RID)
          @options[:guest] ||= User::DOMAIN_GUEST_NAME
          @options[:guest_uid] ||= User.rid2uid(User::DOMAIN_GUEST_RID)
          @options[:guest_gid] ||= Group.rid2gid(Group::DOMAIN_GUESTS_RID)
          @options[:default_user_gid] ||= config[:default_user_gid]
          @options[:default_computer_gid] ||= config[:default_computer_gid]
        end

        def ensure_container_base(dn, target_name, klass, ignore_base=false)
          entries = []
          suffixes = []
          dn.split(/,/).reverse_each do |suffix|
            name, value = suffix.split(/=/, 2)
            next unless name == target_name
            container_class = Class.new(klass)
            prefix = suffixes.reverse.join(",")
            suffixes << suffix
            if ignore_base
              container_class.ldap_mapping :prefix => "", :scope => :base
              container_class.instance_variable_set("@base", prefix)
            else
              container_class.ldap_mapping :prefix => prefix, :scope => :base
            end
            next if container_class.exists?(value, :prefix => suffix)
            container = container_class.new(value)
            yield(container) if block_given?
            container.save!
            entries << container
          end
          entries
        end

        def ensure_base
          ensure_container_base(@base.base, "dc", Dc, true) do |dc|
            dc.o = dc.dc
          end
        end

        def ensure_ou_base(dn)
          ensure_container_base(dn, "ou", Ou)
        end

        def ensure_user_base
          ensure_ou_base(@options[:user_class].prefix)
        end

        def ensure_group_base
          ensure_ou_base(@options[:group_class].prefix)
        end

        def ensure_computer_base
          ensure_ou_base(@options[:computer_class].prefix)
        end

        def ensure_idmap_base
          ensure_ou_base(@options[:idmap_class].prefix)
        end

        def make_user(user_class, name, uid, group)
          if user_class.exists?(name)
            user = user_class.find(name)
            group = nil
          else
            user = user_class.new(name)
            user.init(uid, group)
            user.save!
            group.users << user
          end
          [user, group]
        end

        def make_users
          user_class = @options[:user_class]
          group_class = @options[:group_class]
          entries = []
          [
           [@options[:administrator], @options[:administrator_uid],
            @options[:administrator_gid]],
           [@options[:guest], @options[:guest_uid], @options[:guest_gid]],
          ].each do |name, uid, gid|
            user, group = make_user(user_class, name, uid,
                                    group_class.find_by_gid_number(gid))
            entries << user
            if group
              old_group = entries.find do |entry|
                entry.is_a?(group_class) and entry.cn == group.cn
              end
              index = entries.index(old_group)
              if index
                entries[index] = group
              else
                entries << group
              end
            end
          end
          entries
        end

        def make_group(group_class, name, gid, description=nil, type=nil)
          if group_class.exists?(name)
            group = group_class.find(name)
          else
            group = group_class.new(name)
            group.change_type(type || "domain")
            group.display_name = name
            group.description = name || description
            group.change_gid_number(gid)

            group.save!
          end
          group
        end

        def make_groups
          group_class = @options[:group_class]
          entries = []
          [
           ["Domain Admins", @options[:administrator_gid],
            "Netbios Domain Administrators"],
           ["Domain Users", @options[:default_user_gid],
            "Netbios Domain Users"],
           ["Domain Guests", @options[:guest_gid],
            "Netbios Domain Guest Users"],
           ["Domain Computers", @options[:default_computer_gid],
            "Netbios Domain Computers"],
           ["Administrators", nil, nil, "builtin", Group::LOCAL_ADMINS_RID],
           ["Users", nil, nil, "builtin", Group::LOCAL_USERS_RID],
           ["Guests", nil, nil, "builtin", Group::LOCAL_GUESTS_RID],
           ["Power Users", nil, nil, "builtin", Group::LOCAL_POWER_USERS_RID],
           ["Account Operators", nil, nil, "builtin",
            Group::LOCAL_ACCOUNT_OPERATORS_RID],
           ["System Operators", nil, nil, "builtin",
            Group::LOCAL_SYSTEM_OPERATORS_RID],
           ["Print Operators", nil, nil, "builtin",
            Group::LOCAL_PRINT_OPERATORS_RID],
           ["Backup Operators", nil, nil, "builtin",
            Group::LOCAL_BACKUP_OPERATORS_RID],
           ["Replicators", nil, nil, "builtin",
            Group::LOCAL_REPLICATORS_RID],
          ].each do |name, gid, description, type, rid|
            gid ||= group_class.rid2gid(rid)
            entries << make_group(group_class, name, gid, description, type)
          end
          entries
        end

        def make_pool
          config = @base.configuration
          pool = @options[:unix_id_pool_class].new(config[:samba_domain])
          pool.samba_sid = config[:sid]
          pool.uid_number = @options[:start_uid]
          pool.gid_number = @options[:start_gid]
          pool.save!
          [pool]
        end
      end
    end
  end
end
