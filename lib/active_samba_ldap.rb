require_gem_if_need = Proc.new do |library_name, gem_name, *options|
  begin
    require library_name
  rescue LoadError
    require 'rubygems'
    gem gem_name, *options
    require library_name
  end
end

required_active_ldap_version = ">= 1.1.1"
require_gem_if_need.call("active_ldap", "activeldap",
                         required_active_ldap_version)

if ActiveSupport.const_defined?(:Dependencies)
  dependencies = ActiveSupport::Dependencies
else
  dependencies = Dependencies
end

if dependencies.respond_to?(:load_paths)
  dependencies.load_paths << File.expand_path(File.dirname(__FILE__))
end

require 'active_samba_ldap/version'
require 'active_samba_ldap/get_text_support'
require 'active_samba_ldap/base'
require "active_samba_ldap/configuration"
require 'active_samba_ldap/populate'

ActiveSambaLdap::Base.class_eval do
  include ActiveSambaLdap::Configuration
  include ActiveSambaLdap::Populate
end

require 'active_samba_ldap/user'
require 'active_samba_ldap/group'
require 'active_samba_ldap/computer'
require 'active_samba_ldap/idmap'
require 'active_samba_ldap/unix_id_pool'
require 'active_samba_ldap/ou'
require 'active_samba_ldap/dc'
