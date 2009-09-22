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

# For Hoe's no user friendly default behavior. :<
File.open("README.txt", "w") {|file| file << "= Dummy README\n== XXX\n"}
FileUtils.cp("NEWS.en", "History.txt")
at_exit do
  FileUtils.rm_f("README.txt")
  FileUtils.rm_f("History.txt")
end

ENV["VERSION"] = ActiveSambaLdap::VERSION
project = Hoe.spec("activesambaldap") do
  self.version = ActiveSambaLdap::VERSION
  self.rubyforge_name = "asl"
  self.summary = "Samba+LDAP administration tools"
  self.extra_deps << ["activeldap", required_active_ldap_version]
  self.email = ["kou@clear-code.com"]
  self.author = "Kouhei Sutou"
  self.url = "http://asl.rubyforge.org/"

  news_of_current_release = File.read("NEWS.en").split(/^==\s.*$/)[1]
  self.changes = cleanup_white_space(news_of_current_release)

  entries = File.read("README.en").split(/^==\s(.*)$/)
  whats_this = cleanup_white_space(entries[entries.index("Description") + 1])
  self.summary, self.description, = whats_this.split(/\n\n+/, 3)
end


rdoc_main = "README.en"

rdoc_task = nil
if ObjectSpace.each_object(Rake::RDocTask) {|rdoc_task|} != 1
  puts "hoe may be changed"
end
rdoc_task.main = rdoc_main
rdoc_task.options.delete("-d")
rdoc_task.options << "--charset=UTF-8"
rdoc_task.rdoc_files -= project.spec.executables
rdoc_task.rdoc_files += project.spec.executables.collect {|x| "bin/#{x}.help"}
rdoc_task.rdoc_files += project.spec.files.find_all {|x| /\.(en|ja)\z/ =~ x}
rdoc_task.rdoc_files.reject! {|file| /\Atest-unit\// =~ file}

rdoc_options = rdoc_task.option_list
output_option_index = rdoc_options.index("-o")
rdoc_options[output_option_index, 2] = nil
project.spec.rdoc_options = rdoc_options
project.spec.extra_rdoc_files = rdoc_task.rdoc_files

project.spec.executables.each do |bin|
  bin = "bin/#{bin}"
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

task :docs do
  css_file = "doc/rdoc.css"
  css = File.read(css_file)
  reset_spacing = Regexp.escape("*{ padding: 0; margin: 0; }")
  customized_css = css.sub(/#{reset_spacing}/, '')
  if css != customized_css
    File.open(css_file, "w") do |output|
      output.print(customized_css)
    end
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

desc "Update *.po/*.pot files and create *.mo from *.po files"
task :gettext => ["gettext:po:update", "gettext:mo:create"]

namespace :gettext do
  desc "Setup environment for GetText"
  task :environment do
    require "gettext/tools"
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
      GetText.create_mofiles
    end
  end
end

task(:gem).prerequisites.unshift("gettext:mo:create")
