require_dependency 'active_samba_ldap'
ActiveSambaLdap::Base.logger ||= RAILS_DEFAULT_LOGGER
ldap_configuration_file = File.join(RAILS_ROOT, 'config', 'ldap.yml')
ActiveSambaLdap::Base.configurations =
  ActiveSambaLdap::Configuration.read(ldap_configuration_file)
ActiveSambaLdap::Base.establish_connection
