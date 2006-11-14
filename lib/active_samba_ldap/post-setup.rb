File.open("configuration_files", "w") do |f|
  %w(config.yaml bind.yaml).each do |file|
    f.puts(File.join(config("sysconfdir"), "activesambaldap", file))
  end
end
