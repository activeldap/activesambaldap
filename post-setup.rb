config_file = File.join("lib", "active_samba_ldap", "configuration_files")
File.open(config_file, "w") do |f|
  %w(config.yaml bind.yaml).each do |file|
    f.puts(File.join(config("sysconfdir"), "activesambaldap", file))
  end
end
