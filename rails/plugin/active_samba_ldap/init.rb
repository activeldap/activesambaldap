require_library_or_gem 'active_samba_ldap'
ActiveSambaLdap::Base.logger ||= RAILS_DEFAULT_LOGGER
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
