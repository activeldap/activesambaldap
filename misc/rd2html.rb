#!/usr/bin/env ruby

top = File.expand_path(File.join(File.dirname(__FILE__), ".."))
html_dir = File.join(top, "html")

require "fileutils"

css = "base.css"
kcode = "utf8"

options = [
  "-I#{File.join(top, 'misc')}",
  "-S",
  "rd2",
  "-rrd/rd2html-lib",
  "--out-code=#{kcode}",
  proc do |f|
    "--html-title=#{File.basename(f)}"
  end,
#   proc do |f|
#     "--with-css=#{css}"
#   end,
  proc do |f|
    f
  end
]

Dir[File.join(top, "*.{ja,en}")].each do |f|
  if /(README|NEWS)\.(ja|en)\z/ =~ f
    args = options.collect do |x|
      if x.respond_to?(:call)
        x.call(f)
      else
        x
      end
    end
    output_base = File.basename(f).downcase.sub(/(ja|en)\z/, "html.\\1")
    File.open(File.join(html_dir, output_base), "w") do |out|
      out.puts(`ruby #{args.flatten.join(' ')}`)
    end
  end
end
