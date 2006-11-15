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

        opts.on_tail("--config=CONFIG",
                     "Specify configuration file",
                     "Default configuration files:",
                     *configuration_files.collect {|x| "  #{x}"}) do |file|
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

      begin
        opts.parse!(argv)
      rescue ParseError
        $stderr.puts($!)
        $stderr.puts(opts)
        exit 1
      end

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
      configuration_files = File.join(File.dirname(__FILE__),
                                      "configuration_files")
      if File.exists?(configuration_files)
        files = File.readlines(configuration_files).collect do |line|
          line.strip
        end.reject do |line|
          line.empty? or /^#/ =~ line
        end
      else
        files = [
          "/etc/activesambaldap/config.yaml",
          "/etc/activesambaldap/bind.yaml",
        ]
      end
      begin
        configuration_files_for_user = [
          File.expand_path(File.join("~", ".activesambaldap.conf")),
          File.expand_path(File.join("~", ".activesambaldap.bind")),
        ]
        files.concat(configuration_files_for_user)
      rescue ArgumentError
      end
      files
    end

    def read_configuration_files(files)
      return if files.empty?
      Base.configurations = files.inject({}) do |result, file|
        if File.readable?(file)
          result.merge(Configuration.read(file))
        else
          result
        end
      end
    end
  end
end
