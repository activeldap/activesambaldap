def require_gem_if_need(name, gem_name=nil, *options)
  begin
    require name
  rescue LoadError
    require 'rubygems'
    gem_name ||= name
    require_gem gem_name, *options
  end
end

require_gem_if_need("active_record", "activerecord")

require 'active_samba_ldap/version'
begin
  require "active_samba_ldap/config"
rescue LoadError
  require "active_samba_ldap/default_config"
  module ActiveSambaLdap
    class Config < DefaultConfig
    end
  end
end

require 'active_samba_ldap/base'
require 'active_samba_ldap/populate'

ActiveSambaLdap::Base.class_eval do
  include ActiveSambaLdap::Populate
end

require 'active_samba_ldap/user'
require 'active_samba_ldap/group'
require 'active_samba_ldap/computer'
require 'active_samba_ldap/idmap'
require 'active_samba_ldap/unix_id_pool'
require 'active_samba_ldap/ou'
require 'active_samba_ldap/dc'
