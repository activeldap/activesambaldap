module ActiveSambaLdap
  module GetTextSupport
    class << self
      def included(base)
        base.class_eval do
          include(ActiveLdap::GetText)
          bindtextdomain("active-samba-ldap") if respond_to?(:bindtextdomain)
        end
      end
    end
  end
end
