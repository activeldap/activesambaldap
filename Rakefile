# -*- ruby -*-

require 'find'
require 'fileutils'

base_dir = File.expand_path(File.dirname(__FILE__))
truncate_base_dir = Proc.new do |x|
  x.gsub(/^#{Regexp.escape(base_dir + File::SEPARATOR)}/, '')
end

_binding = binding
eval(File.read("#{base_dir}/lib/active_samba_ldap.rb"), _binding)
eval('require_gem_if_need.call("hoe")', _binding)

manifest = File.join(base_dir, "Manifest.txt")
manifest_contents = []
base_dir_included_components = %w(README.ja README.en NEWS.ja NEWS.en setup.rb
                                  Rakefile)
excluded_components = %w(.svn .test-result .config Manifest.txt config.yml doc
                         pkg html config.yaml)
excluded_suffixes = %w(.help)
Find.find(base_dir) do |target|
  target = truncate_base_dir[target]
  components = target.split(File::SEPARATOR)
  if components.size == 1 and !File.directory?(target)
    next unless base_dir_included_components.include?(components[0])
  end
  Find.prune if (excluded_components - components) != excluded_components
  next if excluded_suffixes.include?(File.extname(target))
  manifest_contents << target if File.file?(target)
end

File.open(manifest, "w") do |f|
  f.puts manifest_contents.sort.join("\n")
end
at_exit do
  FileUtils.rm_f(manifest)
end

def cleanup_white_space(entry)
  entry.gsub(/(\A\n+|\n+\z)/, '') + "\n"
end

class Hoe
  attr_accessor :full_name

  alias_method :announcement_original, :announcement
  def announcement
    name_orig = name
    self.name = full_name
    announcement_original
  ensure
    self_name = name_orig
  end
end

ENV["VERSION"] = ActiveSambaLdap::VERSION
project = Hoe.new("activesambaldap", ActiveSambaLdap::VERSION) do |p|
  p.rubyforge_name = "asl"
  p.name = p.rubyforge_name if ARGV.include?("public_docs")
  p.full_name = "ActiveSambaLdap"
  p.summary = "Samba+LDAP administration tools"
  p.extra_deps << ["activeldap", ">= 0.8.0"]
  p.email = "kou@cozmixng.org"
  p.author = "Kouhei Sutou"
  p.url = "http://asl.rubyforge.org/"
  p.rdoc_pattern = /^(lib|bin)|txt$|\.(en|ja)$/

  news_of_current_release = File.read("NEWS.en").split(/^==\s.*$/)[1]
  p.changes = cleanup_white_space(news_of_current_release)

  entries = File.read("README.en").split(/^==\s(.*)$/)
  whats_this = cleanup_white_space(entries[entries.index("What\'s this?") + 1])
  p.summary, p.description, = whats_this.split(/\n\n+/, 3)
end

rdoc_task = nil
if ObjectSpace.each_object(Rake::RDocTask) {|rdoc_task|} != 1
  puts "hoe may be changed"
end
rdoc_task.main = "README.en"
rdoc_task.options << "--charset=UTF-8"
rdoc_task.template = "kilmer"
rdoc_task.rdoc_files -= project.bin_files
rdoc_task.rdoc_files += project.bin_files.collect {|x| "#{x}.help"}

project.bin_files.each do |bin|
  bin_help = "#{bin}.help"
  File.open(bin_help, "w") do |f|
    f.puts(`#{RUBY} -I #{File.join(base_dir, 'lib')} #{bin} --help`)
  end
  at_exit do
    FileUtils.rm_f(bin_help)
  end
end

desc 'Tag the repository for release.'
task :tag do
  version = ActiveSambaLdap::VERSION
  message = "Released ActiveSambaLdap #{version}!"
  base = "svn+ssh://#{ENV['USER']}@rubyforge.org/var/svn/asl/"
  sh 'svn', 'copy', '-m', message, "#{base}trunk", "#{base}tags/#{version}"
end
