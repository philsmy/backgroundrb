require 'socket'
require 'yaml'
require 'erb'
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
      set_environment = RAILS_ENV.to_sym

      # block for deep_merging the hashes
      deep_proc = Proc.new do |key, oldval, newval|
        if oldval.kind_of?(Hash) && newval.kind_of?(Hash)
          next oldval.merge(newval,&deep_proc)
        end
        next newval
      end
      
      if config[set_environment]
        config.merge!( config[set_environment], &deep_proc)
        if config[set_environment][:schedules]
          config[:schedules].merge!( config[set_environment][:schedules], &deep_proc)
        end
      end
      
      hn = ENV["BDRB_HOSTNAME"] || Socket.gethostname
      hostname = hn.to_sym
      if config[hostname]
        puts "Loading config for #{hostname}"
        config.merge!( config[hostname], &deep_proc)
        if config[hostname][:environment] and config[hostname][:environment] != RAILS_ENV
          # this environment might be different
          environment = config[hostname][:environment]
          puts "setting environment to: #{environment}"
          ENV["RAILS_ENV"] = environment.to_s
        end
        
        if config[hostname][:schedules]
          config[:schedules].merge!( config[hostname][:schedules], &deep_proc)
        end
      else
        puts "Failed to find backgroundrb hostname #{hostname}"
      end
      
      config
    end
  end
end

