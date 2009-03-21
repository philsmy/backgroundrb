module BackgrounDRb
  class Config
    def self.parse_cmd_options(argv)
      options = { }

      OptionParser.new do |opts|
        script_name = File.basename($0)
        opts.banner = "Usage: #{$0} [options]"
        opts.separator ""
        opts.on("-e", "--environment=name", String,
                "Specifies the environment to operate under (test/development/production).",
                "Default: development") { |v| options[:environment] = v }
        opts.separator ""
        opts.on("-h", "--help",
                "Show this help message.") { $stderr.puts opts; exit }
        opts.separator ""
        opts.on("-v","--version",
                "Show version.") { $stderr.puts "1.1"; exit }
        opts.separator ""
        opts.on("-H", "--hostname=name", String,
                "Specifies the hostname to operate under.",
                "Default: #{Socket.gethostname.to_sym}") { |v| options[:hostname] = v }
      end.parse!(argv)

      ENV["RAILS_ENV"] = options[:environment] if options[:environment]
      ENV["BDRB_HOSTNAME"] = options[:hostname] if options[:hostname]
    end

    def self.read_config(config_file)
      config = YAML.load(ERB.new(IO.read(config_file)).result)
      environment = ENV["RAILS_ENV"] || config[:backgroundrb][:environment] || "development"

      if respond_to?(:silence_warnings)
        silence_warnings do
          Object.const_set("RAILS_ENV",environment)
        end
      else
        Object.const_set("RAILS_ENV",environment)
      end

      # block for deep_merging the hashes
      deep_proc = Proc.new do |key, oldval, newval|
        if oldval.kind_of?(Hash) && newval.kind_of?(Hash)
          next oldval.merge(newval,&deep_proc)
        end
        next newval
      end

      if config[environment]
        config.merge!( config[environment], &deep_proc)
        if config[environment][:schedules]
          config[:schedules].merge!( config[environment][:schedules], &deep_proc)
        end
      end

      hostname = ENV["BDRB_HOSTNAME"].to_sym || Socket.gethostname.to_sym
      if config[hostname]
        config.merge!( config[hostname], &deep_proc)
        if config[hostname][:schedules]
          config[:schedules].merge!( config[hostname][:schedules], &deep_proc)
        end
      else
        puts "Failed to find backgroundrb hostname #{hostname}"
      end

      ENV["RAILS_ENV"] = environment
      config
    end
  end
end

