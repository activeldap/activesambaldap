require 'socket'

module ActiveSambaLdap
  module Configuration
    def self.included(base)
      base.extend(ClassMethods)
    end

    class << self
      def read(file)
        require 'yaml'
        require 'erb'
        erb = ERB.new(File.read(file))
        erb.filename = file
        result = nil
        begin
          begin
            result = YAML.load(erb.result)
            unless result
              raise InvalidConfigurationFormatError.new(file, "0",
                                                        "empty source")
            end
          rescue ArgumentError
            if /syntax error on line (\d+), col (\d+): `(.*)'/ =~ $!.message
              raise InvalidConfigurationFormatError.new(file, "#{$1}:#{$2}", $3)
            else
              raise
            end
          end
        rescue InvalidConfigurationFormatError
          raise
        rescue Exception
          file, location = $@.first.split(/:/, 2)
          detail = "#{$!.class}: #{$!.message}"
          raise InvalidConfigurationFormatError.new(file, location, detail)
        end
        result
      end
    end

    module ClassMethods
      class ValidHash < Hash
        def [](name)
          if Private.required_variables.include?(name) and !has_key?(name)
            raise RequiredVariableIsNotSet.new(name)
          end
          super(name)
        end
      end

      def merge_configuration(config)
        config = config.symbolize_keys
        config = (configurations["common"] || {}).symbolize_keys.merge(config)
        ValidHash.new.merge(super(Private.new(config).merge))
      end

      def required_configuration_variables(*names)
        config = configuration
        if config.nil?
          missing_variables = names
        else
          missing_variables = names.find_all do |name|
            config[name.to_sym].nil?
          end
        end
        unless missing_variables.empty?
          raise RequiredVariablesAreNotSet.new(missing_variables)
        end
      end

      class Private
        VARIABLES = %w(base host port scope bind_dn
                       password method allow_anonymous

                       sid smb_conf samba_domain samba_netbios_name
                       hash_encrypt

                       users_prefix groups_prefix computers_prefix
                       idmap_prefix

                       start_uid start_gid

                       user_login_shell user_home user_home_directory_mode
                       user_gecos user_samba_home user_profile
                       user_home_drive user_script mail_domain

                       skeleton_directory

                       default_user_gid default_computer_gid
                       default_max_password_age)

        class << self
          def required_variables
            @required_variables ||= compute_required_variables
          end

          def compute_required_variables
            not_required_variables = %w(base ldap_scope)
            (VARIABLES - public_methods - not_required_variables).collect do |x|
              x.to_sym
            end
          end
        end

        def initialize(target)
          @target = target.symbolize_keys
        end

        def merge
          result = @target.dup
          VARIABLES.each do |variable|
            result[variable.to_sym] ||= send(variable) if respond_to?(variable)
          end
          result
        end

        def [](name)
          @target[name.to_sym] || (respond_to?(name) ? send(name) : nil)
        end

        def sid
          result = `net getlocalsid`
          if $?.success?
            result.chomp.gsub(/\G[^:]+:\s*/, '')
          else
            nil
          end
        end

        def smb_conf
          %w(/etc/samba/smb.conf /usr/local/etc/samba/smb.conf).each do |guess|
            return guess if File.exist?(guess)
          end
          nil
        end

        def samba_domain
          _smb_conf = self["smb_conf"]
          if _smb_conf
            File.open(_smb_conf) do |f|
              f.read.grep(/^\s*[^#;]/).each do |line|
                if /^\s*workgroup\s*=\s*(\S+)\s*$/i =~ line
                  return $1.upcase
                end
              end
            end
          else
            nil
          end
        end

        def samba_netbios_name
          netbios_name = nil
          _smb_conf = self["smb_conf"]
          if _smb_conf
            File.open(_smb_conf) do |f|
              f.read.grep(/^\s*[^#;]/).each do |line|
                if /^\s*netbios\s*name\s*=\s*(.+)\s*$/i =~ line
                  netbios_name = $1
                  break
                end
              end
            end
          end
          netbios_name ||= Socket.gethostname
          netbios_name ? netbios_name.upcase : nil
        end

        def host
          "localhost"
        end

        def port
          389
        end

        def allow_anonymous
          false
        end

        def method
          :plain
        end

        def users_prefix
          retrieve_value_from_smb_conf(/ldap\s+user\s+suffix/i) || "ou=Users"
        end

        def groups_prefix
          retrieve_value_from_smb_conf(/ldap\s+group\s+suffix/i) || "ou=Groups"
        end

        def computers_prefix
          retrieve_value_from_smb_conf(/ldap\s+machine\s+suffix/i) ||
            "ou=Computers"
        end

        def idmap_prefix
          retrieve_value_from_smb_conf(/ldap\s+idmap\s+suffix/i) || "ou=Idmap"
        end

        def start_uid
          "10000"
        end

        def start_gid
          "10000"
        end

        def default_user_gid
          rid = ActiveSambaLdap::Group::DOMAIN_USERS_RID
          ActiveSambaLdap::Group.rid2gid(rid)
        end

        def default_computer_gid
          rid = ActiveSambaLdap::Group::DOMAIN_COMPUTERS_RID
          ActiveSambaLdap::Group.rid2gid(rid)
        end

        def skeleton_directory
          "/etc/skel"
        end

        def user_samba_home
          netbios_name = self["samba_netbios_name"]
          netbios_name ? "\\\\#{netbios_name}\\%U" : nil
        end

        def user_profile
          netbios_name = self["samba_netbios_name"]
          netbios_name ? "\\\\#{netbios_name}\\profiles\\%U" : nil
        end

        def user_home
          "/home/%U"
        end

        def user_login_shell
          "/nonexistent"
        end

        def user_home_drive
          "H:"
        end

        def user_script
          "logon.bat"
        end

        def user_gecos
          nil
        end

        def bind_dn
          nil
        end

        private
        def retrieve_value_from_smb_conf(key)
          smb_conf = self['smb_conf']
          if smb_conf and File.readable?(smb_conf)
            line = File.read(smb_conf).grep(key).reject do |l|
              /^\s*[#;]/ =~ l
            end.first
            if line
              line.split(/=/, 2)[1].strip
            else
              nil
            end
          else
            nil
          end
        end
      end
    end
  end
end
