require_library_or_gem 'active_samba_ldap'

ActiveSambaLdap::Base.logger ||= RAILS_DEFAULT_LOGGER

required_version = ["0", "0", "6"]
if (ActiveLdap::VERSION.split(".") <=> required_version) < 0
  ActiveLdap::Base.class_eval do
    format = _("You need ActiveSambaLdap %s or later")
    logger.error(format % required_version.join("."))
  end
end

ldap_configuration_file = File.join(RAILS_ROOT, 'config', 'ldap.yml')
if File.exist?(ldap_configuration_file)
  ActiveSambaLdap::Base.configurations =
    ActiveSambaLdap::Configuration.read(ldap_configuration_file)
  ActiveSambaLdap::Base.establish_connection
else
  ActiveLdap::Base.class_eval do
    format = _("You should run 'script/generator scaffold_active_samba_ldap' " \
               "to make %s.")
    logger.error(format % ldap_configuration_file)
  end
end

class ActionView::Base
  include ActiveLdap::Helper
end

require 'active_ldap/action_controller/ldap_benchmarking'
class ActionController::Base
  include ActiveLdap::ActionController::LdapBenchmarking
end
