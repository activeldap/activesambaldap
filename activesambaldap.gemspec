# -*- mode: ruby; coding: utf-8 -*-

clean_white_space = lambda do |entry|
  entry.gsub(/(\A\n+|\n+\z)/, '') + "\n"
end

Gem::Specification.new do |spec|
  base_dir = File.expand_path(File.dirname(__FILE__))
  $LOAD_PATH.unshift(File.join(base_dir, 'lib'))
  require 'active_samba_ldap/version'

  collect_files = lambda do |*globs|
    files = []
    globs.each do |glob|
      files.concat(Dir.glob(glob))
    end
    files.uniq.sort
  end

  spec.name = 'activesambaldap'
  spec.version = ActiveSambaLdap::VERSION.dup
  spec.rubyforge_project = 'asl'
  spec.authors = ["Kouhei Sutou"]
  spec.email = ["kou@clear-code.com"]
  spec.summary = "Samba+LDAP administration tools"
  spec.homepage = "http://github.com/activeldap/activesambaldap"
  spec.files = collect_files.call("{lib,rails,rails_generator}/**/*",
                                  "bin/*",
                                  "{examples,po,misc}/**/*",
                                  "license/*",
                                  "Rakefile",
                                  "Gemfile",
                                  "NEWS*",
                                  "README.*")
  spec.files.delete_if {|file| /\.help\z/ =~ File.basename(file)}
  spec.files.delete_if {|file| /\.yaml\z/ =~ File.basename(file)}
  spec.test_files = collect_files.call("test/**/*.rb",
                                       "test/config.yaml.sample")

  entries = File.read("README.en").split(/^==\s(.*)$/)
  whats_this = clean_white_space.call(entries[entries.index("Description") + 1])
  spec.summary, spec.description, = whats_this.split(/\n\n+/, 3)
  spec.license = "LGPLv2.1 or later"

  spec.add_dependency("activeldap")

  spec.add_development_dependency("bundler")
  spec.add_development_dependency("rake")
  spec.add_development_dependency("yard")
  spec.add_development_dependency("test-unit")
  spec.add_development_dependency("test-unit-notify")
end
