#!/usr/bin/ruby

if ARGV.size != 1
  puts "USAGE: #{$0} repository_path"
  exit 1
end

require 'webrick'
require 'webrick/httpservlet/svnhandler'

repos_path = ARGV.shift

log = WEBrick::Log.new
log.level = WEBrick::Log::DEBUG if $DEBUG
server = WEBrick::HTTPServer.new({:Port => 10080, :Logger => log})
server.mount("/", WEBrick::HTTPServlet::SvnHandler, repos_path)
trap(:INT){server.shutdown}
server.start
