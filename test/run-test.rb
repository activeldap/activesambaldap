#!/usr/bin/env ruby

$VERBOSE = true

$KCODE = 'u'

top_dir = File.join(File.dirname(__FILE__), "..")

$LOAD_PATH.unshift(File.join(top_dir, "test-unit", "lib"))
require 'test/unit'

# $LOAD_PATH.unshift(File.join(top_dir, "..", "ldap", "lib"))
# $LOAD_PATH.unshift(File.join(top_dir, "..", "ldap"))
$LOAD_PATH.unshift(File.join(top_dir, "..", "activeldap", "lib"))
$LOAD_PATH.unshift(File.join(top_dir, "lib"))
$LOAD_PATH.unshift(File.join(top_dir, "test"))

ARGV.unshift("--priority")

require 'timeout'
Test::Unit::ErrorHandler::NOT_PASS_THROUGH_EXCEPTIONS << Timeout::Error

exit Test::Unit::AutoRunner.run(true, File.join(top_dir, "test"))
