require 'socket'

module ActiveSambaLdap
  class DefaultConfig
    FILES = [
             "/etc/activesambaldap/config.rb",
             "/etc/activesambaldap/bind.rb",
            ]
    begin
      FILES << File.expand_path("~/.activesambaldap.conf")
      FILES << File.expand_path("~/.activesambaldap.bind")
    rescue ArgumentError
    end

    cattr_writer :sid, :smb_conf, :samba_domain, :samba_netbios_name

    cattr_writer :update_host, :update_port, :update_bind_format
    cattr_writer :update_allow_anonymous
    cattr_accessor :update_user, :update_password, :update_use_tls

    cattr_writer :reference_host, :reference_port
    cattr_writer :reference_bind_format, :reference_user, :reference_password
    cattr_writer :reference_use_tls
    cattr_writer :reference_allow_anonymous

    cattr_accessor :suffix
    cattr_writer :users_prefix, :groups_prefix
    cattr_writer :computers_prefix, :idmap_prefix

    cattr_accessor :scope, :hash_encrypt

    cattr_writer :start_uid, :start_gid

    cattr_accessor :user_login_shell, :user_home, :user_home_directory_mode
    cattr_accessor :user_gecos
    cattr_writer :default_user_gid, :default_computer_gid
    cattr_writer :skeleton_directory
    cattr_accessor :default_max_password_age

    cattr_writer :user_samba_home, :user_profile, :user_home_drive, :user_script
    cattr_accessor :mail_domain

    class << self
      def read(path)
        if File.exist?(path)
          anonymous_binding = Module.new.__send__(:binding)
          eval(File.read(path), anonymous_binding, path, 0)
          eval("local_variables", anonymous_binding).each do |name|
            setter = "#{name}="
            if self.respond_to?(setter)
              self.__send__(setter, eval(name, anonymous_binding))
            end
          end
        end
      end

      def [](key)
        required_variables key
        __send__(key)
      end

      @@initialized = false
      def initialized?
        @@initialized
      end

      def init
        reinit unless initialized?
      end

      def reinit
        FILES.each do |file|
          read(file)
        end
        @@initialized = true
      end

      def required_variables(*names)
        names.each do |name|
          raise RequiredVariableIsNotSet.new(name) if __send__(name).nil?
        end
      end

      def sid
        return @@sid if @@sid
        result = `net getlocalsid`
        if $?.success?
          result.chomp.gsub(/\G[^:]+:\s*/, '')
        else
          nil
        end
      end

      def smb_conf
        return @@smb_conf if @@smb_conf
        %w(/etc/samba/smb.conf /usr/local/etc/samba/smb.conf).each do |guess|
          return guess if File.exist?(guess)
        end
        nil
      end

      def samba_domain
        return @@samba_domain if @@samba_domain
        if smb_conf
          File.open(smb_conf) do |f|
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
        return @@samba_netbios_name if @@samba_netbios_name
        netbios_name = nil
        if smb_conf
          File.open(smb_conf) do |f|
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

      def update_host
        @@update_host || "localhost"
      end

      def update_port
        @@update_port || 389
      end

      def update_bind_format
        return @@update_bind_format if @@update_bind_format
        _suffix = suffix
        if suffix
          "cn=%s,#{suffix}"
        else
          nil
        end
      end

      def update_allow_anonymous
        if @@update_allow_anonymous.nil?
          false
        else
          @@update_allow_anonymous
        end
      end

      def reference_host
        @@reference_host || update_host
      end

      def reference_port
        @@reference_port || update_port
      end

      def reference_bind_format
        @@reference_bind_format || update_bind_format
      end

      def reference_user
        @@reference_user || update_user
      end

      def reference_password
        @@reference_password || update_password
      end

      def reference_use_tls
        if @@reference_use_tls.nil?
          update_use_tls
        else
          @@reference_use_tls
        end
      end

      def reference_allow_anonymous
        if @@reference_allow_anonymous.nil?
          update_allow_anonymous
        else
          @@reference_allow_anonymous
        end
      end

      def users_prefix
        @@users_prefix || "ou=Users"
      end

      def groups_prefix
        @@groups_prefix || "ou=Groups"
      end

      def computers_prefix
        @@computers_prefix || "ou=Computers"
      end

      def idmap_prefix
        @@idmap_prefix || "ou=Idmap"
      end

      def start_uid
        @@start_uid || "10000"
      end

      def start_gid
        @@start_gid || "10000"
      end

      def default_user_gid
        return @@default_user_gid if @@default_user_gid
        rid = ActiveSambaLdap::Group::DOMAIN_USERS_RID
        ActiveSambaLdap::Group.rid2gid(rid)
      end

      def default_computer_gid
        return @@default_computer_gid if @@default_computer_gid
        rid = ActiveSambaLdap::Group::DOMAIN_COMPUTERS_RID
        ActiveSambaLdap::Group.rid2gid(rid)
      end

      def skeleton_directory
        @@skeleton_directory || "/etc/skel"
      end

      def user_samba_home
        return @@user_samba_home if @@user_samba_home
        samba_netbios_name ? "\\\\#{samba_netbios_name}\\%U" : nil
      end

      def user_profile
        return @@user_profile if @@user_profile
        samba_netbios_name ? "\\\\#{samba_netbios_name}\\profiles\\%U" : nil
      end

      def user_home_drive
        @@user_home_drive || "H:"
      end

      def user_script
        @@user_script || "logon.bat"
      end
    end
  end
end
