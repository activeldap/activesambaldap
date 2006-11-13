# -*- ruby -*-

require 'find'

base_dir = File.expand_path(File.dirname(__FILE__))
truncate_base_dir = Proc.new do |x|
  x.gsub(/^#{Regexp.escape(base_dir + File::SEPARATOR)}/, '')
end

_binding = binding
eval(File.read("#{base_dir}/lib/active_samba_ldap.rb"), _binding)
eval('require_gem_if_need.call("hoe")', _binding)

manifest = File.join(base_dir, "Manifest.txt")
manifest_contents = %w(README Rakefile)
Find.find(File.join(base_dir, "lib")) do |target|
  target = truncate_base_dir[target]
  manifest_contents << target if File.file?(target)
end

File.open(manifest, "w") do |f|
  f.puts manifest_contents.sort.join("\n")
end

def cleanup_white_space(entry)
  entry.gsub(/(\A\n+|\n+\z)/, '') + "\n"
end

Hoe.new("AactiveSambaLdap", ActiveSambaLdap::VERSION) do |p|
  p.rubyforge_name = "asl"
  p.summary = "Samba+LDAP administration tools"
  p.extra_deps << ["activeldap", ">= 0.8.0"]
  p.email = "kou@cozmixng.org"
  p.author = "Kouhei Sutou"
  p.url = "http://asl.rubyforge.org/"

  news_of_current_release = File.read("NEWS.en").split(/^==\s.*$/)[1]
  p.changes = cleanup_white_space(news_of_current_release)

  entries = File.read("README.en").split(/^==\s(.*)$/)
  whats_this = cleanup_white_space(entries[entries.index("What\'s this?") + 1])
  p.summary, p.description, = whats_this.split(/\n\n+/, 3)
end
