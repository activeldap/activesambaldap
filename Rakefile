# -*- ruby -*-

require 'find'

base_dir = File.dirname(__FILE__)
truncate_base_dir = Proc.new do |x|
  x.gsub(/^#{Regexp.escape(base_dir + File::SEPARATOR)}/, '')
end

require "#{base_dir}/lib/active_samba_ldap"
require_gem_if_need("hoe")

manifest = File.join(base_dir, "Manifest.txt")
manifest_contents = %w(README Rakefile)
Find.find(File.join(base_dir, "lib")) do |target|
  target = truncate_base_dir[target]
  manifest_contents << target if File.file?(target)
end

File.open(manifest, "w") do |f|
  f.puts manifest_contents.sort.join("\n")
end

Hoe.new("activesambaldap", ActiveSambaLdap::VERSION) do |p|
  p.summary = "Samba+LDAP administration tools"
  p.extra_deps << ["activeldap", ">= 0.8.0"]
  p.email = "kou@cozmixng.org"
  p.author = "Kouhei Sutou"
  p.url = "http://rubyforge/activesambaldap"
  p.summary = "ActiveSambaLdap is a library and a management tool " \
              "for Samba + LDAP environment."
  p.description = "ActiveSambaLdap provides API to manipulate LDAP " \
                  "data for Samba with ActiveRecord like API.\n" \
                  "ActiveSambaLdap provides also smbldap-tools like " \
                  "command-line tools."
end
