#!/usr/bin/env ruby

$VERBOSE = true

$KCODE = 'u'

top_dir = File.join(File.dirname(__FILE__), "..")
# $LOAD_PATH.unshift(File.join(top_dir, "..", "ldap", "lib"))
# $LOAD_PATH.unshift(File.join(top_dir, "..", "ldap"))
$LOAD_PATH.unshift(File.join(top_dir, "..", "activeldap", "lib"))
$LOAD_PATH.unshift(File.join(top_dir, "lib"))
$LOAD_PATH.unshift(File.join(top_dir, "test"))
$LOAD_PATH.unshift(File.join(top_dir, "test-unit-ext", "lib"))

require 'test-unit-ext'

unless ARGV.find {|opt| /\A--(?:no-)?priority/ =~ opt}
  ARGV << "--priority"
end

if Test::Unit::AutoRunner.respond_to?(:standalone?)
  exit Test::Unit::AutoRunner.run($0, File.dirname($0))
else
  exit Test::Unit::AutoRunner.run(false, File.dirname($0))
end
