module ActiveSambaLdap
  module Entry
    def self.included(base)
      super
      base.extend(ClassMethods)
    end

    module ClassMethods
      def create(attributes=nil)
        pool = nil
        number_key = nil
        attributes ||= {}
        attributes = attributes.stringify_keys
        ensure_ou(attributes[dn_attribute])
        entry = super do |entry|
          options, pool, number_key = prepare_create_options(entry, attributes)
          entry.fill_default_values(options)
          yield entry if block_given?
        end
        if entry.errors.empty? and pool
          pool[number_key] = Integer(entry[number_key]).succ
          unless pool.save
            pool.each do |key, value|
              entry.add("pool: #{key}", value)
            end
          end
        end
        entry
      end

      private
      def ensure_ou(dn)
        return if dn.nil?
        dn_value, ou = dn.split(/,/, 2)
        return if ou.nil?
        prefixes = [prefix]
        ou.split(/\s*,\s*/).reverse_each do |entry|
          name, value = entry.split(/\s*=\s*/, 2).collect {|x| x.strip}
          raise ArgumentError, "#{ou} must be only ou" if name != "ou"
          ou_class = Class.new(ActiveSambaLdap::Ou)
          ou_class.ldap_mapping :prefix => prefixes.join(',')
          prefixes.unshift(entry)
          next if ou_class.exists?(value)
          ou = ou_class.new(value)
          ou.save!
        end
      end

      def prepare_create_options_for_number(key, entry, options)
        options = {key => entry[key]}.merge(options)
        number, pool = ensure_number(key, options)
        [options.merge(key => number), pool, key]
      end

      def ensure_number(key, options)
        number = options[key]
        pool = nil
        unless number
          pool = ensure_pool(options)
          number = pool.send("find_available_#{key}", self)
        end
        [number, pool]
      end

      def ensure_pool(options)
        pool = options[:pool]
        unless pool
          pool_class = options[:pool_class]
          unless pool_class
            pool_class = Class.new(UnixIdPool)
            pool_class.ldap_mapping
          end
          samba_domain = options[:samba_domain]
          samba_domain ||= pool_class.configuration[:samba_domain]
          pool = options[:pool] = pool_class.find(samba_domain)
        end
        pool
      end
    end
  end
end
