#!/usr/bin/env ruby

require "test/unit"

top_dir = File.join(File.dirname(__FILE__), "..")
# $LOAD_PATH.unshift(File.join(top_dir, "..", "ldap", "lib"))
# $LOAD_PATH.unshift(File.join(top_dir, "..", "ldap"))
$LOAD_PATH.unshift(File.join(top_dir, "..", "activeldap", "lib"))
$LOAD_PATH.unshift(File.join(top_dir, "lib"))
$LOAD_PATH.unshift(File.join(top_dir, "test"))

require 'test-unit-ext'

# ARGV.unshift("-tAslGroupModTest")
# ARGV.unshift("-tSambaEncryptTest")
# ARGV.unshift("-ntest_samba_account_flags")
# ARGV.unshift("-ntest_primary_group_of_user_with_force_with_other_group")
# ARGV.unshift("-ntest_belong_to_group")


if Test::Unit::AutoRunner.respond_to?(:standalone?)
  exit Test::Unit::AutoRunner.run($0, File.dirname($0))
else
  exit Test::Unit::AutoRunner.run(false, File.dirname($0))
end
