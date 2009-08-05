module ActiveSambaLdap
  module ActiveDirectory
    module UserAccountControl
      # http://support.microsoft.com/kb/305144/ja
      SCRIPT = 0x0001
      ACCOUNTDISABLE = 0x0002
      ACCOUNT_DISABLE = ACCOUNTDISABLE
      HOMEDIR_REQUIRED = 0x0008
      HOME_DIRECTORY_REQUIRED = HOMEDIR_REQUIRED
      LOCKOUT = 0x0010
      PASSWD_NOTREQD = 0x0020
      PASSWORD_NOT_REQUIRED = PASSWD_NOTREQD

      # To modify this property, see
      # http://msdn.microsoft.com/en-us/library/aa746398(VS.85).aspx
      PASSWD_CANT_CHANGE = 0x0040
      PASSWORD_CANT_CHANGE = PASSWD_CANT_CHANGE

      ENCRYPTED_TEXT_PWD_ALLOWED = 0x0080
      ENCRYPTED_TEXT_PASSWORD_ALLOWED = ENCRYPTED_TEXT_PWD_ALLOWED
      TEMP_DUPLICATE_ACCOUNT = 0x0100
      NORMAL_ACCOUNT = 0x0200
      INTERDOMAIN_TRUST_ACCOUNT = 0x0800
      WORKSTATION_TRUST_ACCOUNT = 0x1000
      SERVER_TRUST_ACCOUNT = 0x2000
      DONT_EXPIRE_PASSWORD = 0x10000
      MNS_LOGON_ACCOUNT = 0x20000
      SMARTCARD_REQUIRED = 0x40000
      SMART_CARD_REQUIRED = SMARTCARD_REQUIRED
      TRUSTED_FOR_DELEGATION = 0x80000
      NOT_DELEGATED = 0x100000
      USE_DES_KEY_ONLY = 0x200000
      DONT_REQ_PREAUTH = 0x400000
      DONT_REQUIRE_PREAUTH = DONT_REQ_PREAUTH
      PASSWORD_EXPIRED = 0x800000
      TRUSTED_TO_AUTH_FOR_DELEGATION = 0x1000000
    end

    module GroupType
      GLOBAL_GROUP = 0x2
      DOMAIN_LOCAL_GROUP = 0x4
      UNIVERSAL_GROUP = 0x8

      SECURITY_ENABLED = 0x80000000

      module_function
      def resolve(name, security_enabled=true)
        type = 0
        case name.to_s
        when "global"
          type = GLOBAL_GROUP
        when /\Adomain[-_]local\z/
          type = DOMAIN_LOCAL_GROUP
        when "universal"
          type = UNIVERSAL_GROUP
        else
          # TODO: I18N
          raise ArgumentError, "unknown group type: #{name.inspect}: " +
                               "available: [:global, :domain_local, :universal]"
        end
        type |= SECURITY_ENABLED if security_enabled
        type
      end
    end
  end
end
