require 'svn/repos'

require 'webrick/httpstatus/webdav'
require 'webrick/httpservlet/abstract'

module WEBrick
  module HTTPServlet
    class SvnHandler < AbstractServlet
      def initialize(server, repos_path, options={}, default={})
        super(server, options)
        @repos_path = File.expand_path(repos_path)
      end

      def do_PROPFIND(req, res)
        depth = normalize_depth(req, res)
        check_infinite_depth(req, res, depth)
      end

      private
      def normalize_depth(req, res)
        depth = req['Depth']
        @logger.debug "propfind request depth=#{depth}"
        depth = nil if depth == "infinity"
        begin
          depth = Integer(depth) if depth
        rescue ArgumentError
          res.body = "invalid Depth value: #{depth}"
          raise HTTPStatus::BadRequest
        end
        depth
      end

      def check_infinite_depth(req, res, depth)
        if depth.nil?
          raise HTTPStatus::Forbidden
        end
      end
    end
  end
end
