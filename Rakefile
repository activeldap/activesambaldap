# -*- ruby -*-

require 'find'
require 'fileutils'

base_dir = File.expand_path(File.dirname(__FILE__))
truncate_base_dir = Proc.new do |x|
  x.gsub(/^#{Regexp.escape(base_dir + File::SEPARATOR)}/, '')
end

_binding = binding
file = "#{base_dir}/lib/active_samba_ldap.rb"
eval(File.read(file), _binding, file)
eval('require_gem_if_need.call("hoe")', _binding)
required_active_ldap_version = eval('required_active_ldap_version', _binding)

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
  p.full_name = "ActiveSambaLdap"
  p.summary = "Samba+LDAP administration tools"
  p.extra_deps << ["ruby-activeldap", required_active_ldap_version]
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
rdoc_task.options.delete("-d")
rdoc_task.options << "--charset=UTF-8"
rdoc_task.template = "kilmer"
rdoc_task.rdoc_files -= project.bin_files
rdoc_task.rdoc_files += project.bin_files.collect {|x| "#{x}.help"}

project.bin_files.each do |bin|
  bin_help = "#{bin}.help"
  File.open(bin_help, "w") do |f|
    lang = ENV["LANG"]
    ENV["LANG"] = "C"
    f.puts(`#{RUBY} -I #{File.join(base_dir, 'lib')} #{bin} --help`)
    ENV["LANG"] = lang
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

desc "Distribute new release."
task :dist => [:publish_docs, :release, :tag, :announce]

# # fix Hoe's incorrect guess.
# project.spec.executables.clear
# project.bin_files = project.spec.files.grep(/^bin/)

# fix Hoe's install and uninstall task.
task(:install).instance_variable_get("@actions").clear
task(:uninstall).instance_variable_get("@actions").clear

task :install do
  [
   [project.lib_files, "lib", Hoe::RUBYLIB, 0444],
   [project.bin_files, "bin", File.join(Hoe::PREFIX, 'bin'), 0555]
  ].each do |files, prefix, dest, mode|
    FileUtils.mkdir_p dest unless test ?d, dest
    files.each do |file|
      base = File.dirname(file.sub(/^#{prefix}#{File::SEPARATOR}/, ''))
      _dest = File.join(dest, base)
      FileUtils.mkdir_p _dest unless test ?d, _dest
      install file, _dest, :mode => mode
    end
  end
end

desc 'Uninstall the package.'
task :uninstall do
  Dir.chdir Hoe::RUBYLIB do
    rm_f project.lib_files.collect {|f| f.sub(/^lib#{File::SEPARATOR}/, '')}
  end
  Dir.chdir File.join(Hoe::PREFIX, 'bin') do
    rm_f project.bin_files.collect {|f| f.sub(/^bin#{File::SEPARATOR}/, '')}
  end
end


desc "Update *.po/*.pot files and create *.mo from *.po files"
task :gettext => ["gettext:po:update", "gettext:mo:create"]

namespace :gettext do
  desc "Setup environment for GetText"
  task :environment do
    require "gettext/utils"
  end

  namespace :po do
    desc "Update po/pot files (GetText)"
    task :update => "gettext:environment" do
      module GetText::RGetText
        class << self
          alias_method :generate_pot_original, :generate_pot
          def generate_pot(ary)
            ary = ary.collect {|key, *other| [key.gsub(/\\/, "\\\\\\"), *other]}
            generate_pot_original(ary)
          end
        end
      end
      files = Dir.glob("{lib,rails}/**/*.rb")
      files += Dir.glob("bin/asl*")
      GetText.update_pofiles("active-samba-ldap",
                             files,
                             "Ruby/ActiveSambaLdap #{ActiveSambaLdap::VERSION}")
    end
  end

  namespace :mo do
    desc "Create *.mo from *.po (GetText)"
    task :create => "gettext:environment" do
      GetText.create_mofiles(false)
    end
  end
end

task(:gem).prerequisites.unshift("gettext:mo:create")
