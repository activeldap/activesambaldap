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
        entry = super do |entry|
          options = attributes || {}
          options, pool, number_key = prepare_create_options(entry, options)
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