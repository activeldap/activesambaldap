require "test/unit"

require "stringio"
require "webrick"
require "webrick/httpservlet/svnhandler"

class SvnServletPROPFINDTest < Test::Unit::TestCase
  def handler
    config = {:Logger => WEBrick::Log.new}
    repos_path = "#{File.dirname(__FILE__)}/tmp/repos"
    WEBrick::HTTPServlet::SvnHandler.new(config, repos_path)
  end

  def make_propfind_request_body(dav_props, svn_props)
    default_dav_props = ["version-controlled-configuration",
                         "resourcetype"]
    default_svn_props = ["baseline-relative-path",
                         "repository-uuid"],

    dav_props = (dav_props || []) | default_dav_props
    svn_props = (svn_props || []) | default_svn_props

    dav_props = dav_props.collect {|prop| "<#{prop}/>"}.join("\n")
    svn_ns = ' xmlns="http://subversion.tigris.org/xmlns/dav/"'
    svn_props = svn_props.collect {|prop| "<#{prop}#{svn_ns}/>"}.join("\n")
    <<-EOX
<?xml version="1.0" encoding="utf-8"?>
<propfind xmlns="DAV:">
  <prop>
#{dav_props}
#{svn_props}
  </prop>
</propfind>
EOX
  end

  def make_propfind_request(path, props=nil, depth=0)
    props ||= {}
    body = make_propfind_request_body(props[:dav], props[:svn])
    depth = "Depth: #{depth}" if depth
    header = <<-EOR
PROPFIND #{path} HTTP/1.1
Host: localhost:10080
User-Agent: SVN/1.4.0 (r21228) neon/0.25.5
Content-Length: #{body.length}
Content-Type: text/xml
#{depth}
EOR
    StringIO.new("#{header.strip}\r\n\r\n#{body}")
  end

  def propfind(path, props=nil, depth=0)
    req = WEBrick::HTTPRequest.new(WEBrick::Config::HTTP)
    req.parse(make_propfind_request(path, props, depth))
    res = WEBrick::HTTPResponse.new(WEBrick::Config::HTTP)
    handler.do_PROPFIND(req, res)
    res
  end

  def test_depth
    assert_raises(WEBrick::HTTPStatus::Forbidden) do
      propfind("/", nil, nil)
    end
    assert_raises(WEBrick::HTTPStatus::Forbidden) do
      propfind("/", nil, "infinity")
    end
    assert_raises(WEBrick::HTTPStatus::BadRequest) do
      propfind("/", nil, "NOT-A-NUMBER")
    end

    assert_nothing_raised do
      propfind("/")
    end
  end
end
