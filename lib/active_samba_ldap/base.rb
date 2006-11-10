require_gem_if_need "activeldap", nil, ">= 0.8.0"

module ActiveSambaLdap
  class Error < StandardError
  end

  class RequiredVariableIsNotSet < Error
    attr_reader :name
    def initialize(name)
      @name = name
      super("required variable '#{name}' is not set")
    end
  end

  class UidNumberAlreadyExists < Error
    attr_reader :number
    def initialize(number)
      @number = number
      super("uid number '#{@number}' already exists")
    end
  end

  class GroupDoesNotExist < Error
    attr_reader :name
    def initialize(name)
      @name = name
      super("group '#{@name}' doesn't exist")
    end
  end

  class GidNumberAlreadyExists < Error
    attr_reader :number
    def initialize(number)
      @number = number
      super("gid number '#{@number}' already exists")
    end
  end

  class GidNumberDoesNotExist < Error
    attr_reader :number
    def initialize(number)
      @number = number
      super("gid number '#{@number}' doesn't exist")
    end
  end

  class GroupDoesNotHaveSambaSID < Error
    attr_reader :number
    def initialize(number)
      @number = number
      super("sambaSID attribute doesn't exist for gid number '#{@number}'")
    end
  end

  class CanNotChangePrimaryGroup < Error
    attr_reader :group, :members
    def initialize(group, members)
      @group = group
      @members = members
      message = "cannot change primary group from '#{group}' to other group "
      message << "due to no other belonged groups: #{members.join(', ')}"
      super(message)
    end
  end

  class PrimaryGroupCanNotBeDestroyed < Error
    attr_reader :group, :members
    def initialize(group, members)
      @group = group
      @members = members
      message = "cannot destroy group '#{group}' due to members who belong "
      message << "to the group as primary group: #{members.join(', ')}"
      super(message)
    end
  end

  class Base < ActiveLDAP::Base
    include Reloadable::Subclasses

    OLD_ACTIVE_LDAP = (ActiveLDAP::VERSION.split(/\./) <=> %w(0 8 0)) < 0

    if OLD_ACTIVE_LDAP
      class << ActiveLDAP::Base
        def establish_connection(config={})
          connect(config)
        end
      end

      alias_method :save, :write

      def initialize(val)
        val = val.first if val.is_a?(Array) and val.size == 1
        super(val)
      end

      def update_attribute(name, value)
        if self.attribute_names.member?(name)
          send(:attribute_method=, name, value)
        end
        save
      end

      def update_attributes(h)
        self.attributes = h
        save
      end

      alias_method :attribute_names, :attributes
      def attributes
        Marshal.load(Marshal.dump(@data))
      end

      def attributes=(h)
        if h.respond_to?(:keys) and h.respond_to?(:[])
          h.each_pair do |key, value|
            key = key.to_s.downcase
            if self.attribute_names.member?(key)
              send(:attribute_method=, key, value)
            end
          end
        end
      end
    end

    class << self
      def prefix
        base.gsub(/,?#{Regexp.escape(self.ancestors[1].base)}\z/, '')
      end

      def instantiate(record)
        object = allocate
        object.instance_variable_set("@attributes", record)
        object
      end

      def human_attribute_name(attribute_key_name)
        attribute_key_name.humanize
      end

      def establish_connection(config={}, reference_only=true)
        Config.init
        Config.required_variables :suffix
        default_config = {:base => Config.suffix}
        if reference_only
          Config.required_variables :reference_host, :reference_port
          default_config[:host] = Config.reference_host
          default_config[:port] = Config.reference_port
          default_config[:bind_format] = Config.reference_bind_format
          default_config[:user] = Config.reference_user
          default_config[:password] = Config.reference_password
          default_config[:method] = :tls if Config.reference_use_tls
          default_config[:allow_anonymous] = Config.reference_allow_anonymous
        else
          Config.required_variables :update_host, :update_port
          default_config[:host] = Config.update_host
          default_config[:port] = Config.update_port
          default_config[:bind_format] = Config.update_bind_format
          default_config[:user] = Config.update_user
          default_config[:password] = Config.update_password
          default_config[:method] = :tls if Config.update_use_tls
          default_config[:allow_anonymous] = Config.update_allow_anonymous
        end
        default_config.each do |key, value|
          default_config.delete(key) if value.nil?
        end
        super(default_config.merge(config))
      end

      def destroy_all(config={})
        targets = []
        begin
          targets = search(config).collect do |entry|
            entry["dn"][0]
          end.sort_by do |dn|
            dn.reverse
          end.reverse
	rescue RuntimeError
        end
        return if targets.empty?

        connection do |conn|
          targets.each do |target|
            conn.delete(target)
          end
        end
      end

      def dump(config={})
        ldifs = []
        search(config).each do |entry|
          ldif = LDAP::LDIF.to_ldif("dn", entry.delete("dn"))
          entry.each do |key, values|
            ldif << LDAP::LDIF.to_ldif(key, values)
          end
          ldifs << ldif
        end
        ldifs.join("\n")
      end

      def load(ldifs)
        connection do |conn|
          ldifs.split(/(?:\r?\n){2,}/).each do |ldif|
            LDAP::LDIF.parse_entry(ldif).send(conn)
          end
        end
      end

      def search(*args, &block)
        super(*args, &block)
      rescue RuntimeError
        []
      end

      def exists?(dn_value)
        new(dn_value).exists?
      end

      def restart_nscd
        if system("/etc/init.d/nscd status >/dev/null 2>&1")
          system("/etc/init.d/nscd stop >/dev/null 2>&1")
          begin
            yield if block_given?
          ensure
            system("/etc/init.d/nscd start >/dev/null 2>&1")
          end
        end
      end
    end

    alias_method :respond_to_without_attributes?, :respond_to?

    alias_method :validate_ldap, :validate
    alias_method :save_ldap, :save
    alias_method :destroy, :delete
    alias_method :new_record?, :exists?

    def save!
      enforce_types
      save_ldap
    end

    def save
      create_or_update
    end

    def to_ldif
      ldif = ::LDAP::LDIF.to_ldif("dn", [@dn.dup])
      @data.sort_by do |key, values|
        key
      end.each do |key, values|
        ldif << ::LDAP::LDIF.to_ldif(key, values.collect {|value| value.dup})
      end

      ldif
    end
    alias_method :to_s, :to_ldif

    private
    def create_or_update
      begin
        save!
        true
      rescue RuntimeError => e
        if /^ActiveLDAP::/ =~ e.class.name
          false
        else
          raise
        end
      end
    end

    def create
      save
    end

    def update
      save
    end

    include ActiveRecord::Validations
    include ActiveRecord::Callbacks
  end
end

require "ldap/ldif"

class LDAP::Mod
  unless instance_method(:to_s).arity.zero?
    def to_s
      inspect
    end
  end

  if ActiveSambaLdap::Base::OLD_ACTIVE_LDAP
    alias_method :_initialize, :initialize
    def initialize(op, type, vals)
      if (LDAP::VERSION.split(/\./).collect {|x| x.to_i} <=> [0, 9, 7]) <= 0
        @op, @type, @vals = op, type, vals # to protect from GC
      end
      _initialize(op, type, vals)
    end
  end
end

if ActiveSambaLdap::Base::OLD_ACTIVE_LDAP
  class LDAP::Schema2
    def attr(sub, type, at)
      return [] if sub.empty?
      return [] if type.empty?
      return [] if at.empty?

      type = type.downcase # We're going case insensitive.

      # Check already parsed options first
      if @@attr_cache.has_key? sub \
        and @@attr_cache[sub].has_key? type \
        and @@attr_cache[sub][type].has_key? at
          return @@attr_cache[sub][type][at].dup
      end

      # Initialize anything that is required
      unless @@attr_cache.has_key? sub
        @@attr_cache[sub] = {}
      end
      
      unless @@attr_cache[sub].has_key? type
        @@attr_cache[sub][type] = {}
      end

      at = at.upcase
      self[sub].each do |s|
        line = nil
        if type[0..0] =~ /[0-9]/
          if s =~ /\(\s+(?i:#{type})\s+(?:[A-Z]|\))/
            line = s
          end
        else
          # support NAME 'dsa' or NAME ( 'das' 'dsa' ... )
          if s =~ /NAME\s+(?:(?:\(.*'(?i:#{type})'.*?\))|(?:'(?i:#{type})'))\s+(?:[A-Z]|\))/
            line = s
          end
        end
        next if line.nil?

        # I need to check, but I think some of these matchs
        # overlap. I'll need to check these when I'm less sleepy.
        multi = nil
        case line
          when /#{at}\s+[\)A-Z]/
            @@attr_cache[sub][type][at] = ['TRUE']
            return ['TRUE']
          when /#{at}\s+'(.+?)'/
            @@attr_cache[sub][type][at] = [$1]
            return [$1]
          when /#{at}\s+\((.+?)\)/
            multi = $1
          when /#{at}\s+\(([\w\d\s\.]+)\)/
            multi = $1
          when /#{at}\s+([\w\d\.]+)/
            @@attr_cache[sub][type][at] = [$1]
            return [$1]
        end
        next if multi.nil?
        # Split up multiple matches
        # if oc then it is sep'd by $
        # if attr then bu spaces
        if multi.match(/\$/)
          @@attr_cache[sub][type][at] = multi.split("$").collect{|attr| attr.strip}
          return @@attr_cache[sub][type][at].dup
        elsif not multi.empty?
          @@attr_cache[sub][type][at] = multi.gsub(/'/, '').split(' ').collect{|attr| attr.strip}
          return @@attr_cache[sub][type][at].dup
        end
      end
      @@attr_cache[sub][type][at] = []
      return []
    end
  end
end
