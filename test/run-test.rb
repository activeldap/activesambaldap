#!/usr/bin/env ruby

$LOAD_PATH.unshift(File.expand_path("./lib"))

require "test/unit"

if Test::Unit::AutoRunner.respond_to?(:standalone?)
  exit Test::Unit::AutoRunner.run($0, File.dirname($0))
else
  exit Test::Unit::AutoRunner.run(false, File.dirname($0))
end
