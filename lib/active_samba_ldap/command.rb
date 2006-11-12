require 'optparse'
require 'ostruct'

module ActiveSambaLdap
  module Command
    module_function
    def parse_options(argv=nil)
      argv ||= ARGV.dup
      options = OpenStruct.new
      opts = OptionParser.new do |opts|
        yield(opts, options)

        opts.separator ""
        opts.separator "Common options:"

        opts.on_tail("--config=CONFIG", "Specify configuration file") do |file|
          DefaultConfig::FILES << file
        end

        opts.on_tail("-h", "--help", "Show this message") do
          puts opts
          exit
        end

        opts.on_tail("--version", "Show version") do
          puts VERSION
          exit
        end
      end
      opts.parse!(argv)
      [argv, opts, options]
    end

    def read_password(prompt, input=$stdin, output=$stdout)
      output.print prompt
      system "/bin/stty -echo" if input.tty?
      input.gets.chomp
    ensure
      system "/bin/stty echo" if input.tty?
      output.puts
    end
  end
end
