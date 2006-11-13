require 'optparse'
require 'ostruct'

module ActiveSambaLdap
  module Command
    module_function
    def parse_options(argv=nil)
      argv ||= ARGV.dup
      options = OpenStruct.new
      configuration_files = default_configuration_files
      opts = OptionParser.new do |opts|
        yield(opts, options)

        opts.separator ""
        opts.separator "Common options:"

        opts.on_tail("--config=CONFIG", "Specify configuration file") do |file|
          configuration_files << file
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

      read_configuration_files(configuration_files)

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

    def default_configuration_files
      files = [
        "/etc/activesambaldap/config.rb",
        "/etc/activesambaldap/bind.rb",
      ]
      begin
        configuration_files_for_user = [
          File.expand_path("~/.activesambaldap.conf"),
          File.expand_path("~/.activesambaldap.bind")
        ]
        files.concat(configuration_files_for_user)
      rescue ArgumentError
      end
      files
    end

    def read_configuration_files(files)
      return if files.empty?
      Base.configurations = files.inject({}) do |result, file|
        if File.exist?(file)
          result.merge(Configuration.read(file))
        else
          result
        end
      end
    end
  end
end
