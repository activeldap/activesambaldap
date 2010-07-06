#!/usr/bin/env ruby

$VERBOSE = true

$KCODE = 'u'

base_dir = File.join(File.dirname(__FILE__))
top_dir = File.join(base_dir, "..")

$LOAD_PATH.unshift(File.join(top_dir, "test-unit", "lib"))
require 'test/unit'

# $LOAD_PATH.unshift(File.join(top_dir, "..", "ldap", "lib"))
# $LOAD_PATH.unshift(File.join(top_dir, "..", "ldap"))
$LOAD_PATH.unshift(File.join(top_dir, "..", "activeldap", "lib"))
$LOAD_PATH.unshift(File.join(top_dir, "lib"))

ARGV.unshift("--priority")

require 'timeout'
Test::Unit::ErrorHandler::NOT_PASS_THROUGH_EXCEPTIONS << Timeout::Error

exit Test::Unit::AutoRunner.run(true, base_dir)
