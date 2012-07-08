# -*- ruby -*-

require "find"
require "fileutils"

require "rubygems"
require "yard"
require "bundler/gem_helper"

class Bundler::GemHelper
  def version_tag
    "#{version}"
  end
end

base_dir = File.dirname(__FILE__)

helper = Bundler::GemHelper.new(base_dir)
helper.install
spec = helper.gemspec

# spec.executables.each do |bin|
#   bin = "bin/#{bin}"
#   bin_help = "#{bin}.help"
#   File.open(bin_help, "w") do |f|
#     lang = ENV["LANG"]
#     ENV["LANG"] = "C"
#     f.puts(`#{RUBY} -I #{File.join(base_dir, 'lib')} #{bin} --help`)
#     ENV["LANG"] = lang
#   end
#   at_exit do
#     FileUtils.rm_f(bin_help)
#   end
# end

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
                             "ActiveSambaLdap #{ActiveSambaLdap::VERSION}")
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
