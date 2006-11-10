require 'rbconfig'

require File.join(File.dirname(__FILE__), "command")

module CommandSupport
  def setup
    super
    @fakeroot = "fakeroot"
    @ruby = File.join(Config::CONFIG["bindir"],
                      Config::CONFIG["RUBY_INSTALL_NAME"])
    @top_dir = File.expand_path(File.join(File.dirname(__FILE__), ".."))
    @bin_dir = File.join(@top_dir, "bin")
    @lib_dir = File.join(@top_dir, "lib")
    base = File.join(@top_dir, "..")
    @ruby_args = [
                  "-I", File.join(base, "activesambaldap", "lib"),
                  "-I", File.join(base, "activeldap", "lib"),
#                   "-I", File.join(base, "ldap", "lib"),
#                   "-I", File.join(base, "ldap"),
                 ]
  end

  def run_ruby(*ruby_args, &block)
    args = [@ruby, *@ruby_args]
    args.concat(ruby_args)
    Command.run(*args, &block)
  end

  def run_ruby_with_fakeroot(*ruby_args, &block)
    args = [@fakeroot, @ruby, *@ruby_args]
    args.concat(ruby_args)
    Command.run(*args, &block)
  end
end
