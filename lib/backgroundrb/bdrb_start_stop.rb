module BackgrounDRb
  class StartStop
    def kill_process arg_pid_file
      pid = nil
      pid = File.open(arg_pid_file, "r") { |pid_handle| pid_handle.gets.strip.chomp.to_i }
      pgid =  Process.getpgid(pid)
      puts "Stopping BackgrounDRb with pid #{pid}...."
      Process.kill('-TERM', pgid)
      File.delete(arg_pid_file) if File.exists?(arg_pid_file)
      puts "Success!"
    end
    def running?; File.exists?(PID_FILE); end

    def start
      if fork
        sleep(5)
        exit(0)
      else
        if running?
          puts "pid file already exists, exiting..."
          exit(-1)
        end
        puts "Starting BackgrounDRb .... "
        op = File.open(PID_FILE, "w")
        op.write(Process.pid().to_s)
        op.close
        if BDRB_CONFIG[:backgroundrb][:log].nil? or BDRB_CONFIG[:backgroundrb][:log] != 'foreground'
          log_file = File.open(SERVER_LOGGER,"a")
          [STDIN, STDOUT, STDERR].each {|desc| desc.reopen(log_file)}
        end

        BackgrounDRb::MasterProxy.new()
      end
    end

    def stop
      pid_files = Dir["#{RAILS_HOME}/tmp/pids/backgroundrb_*.pid"]
      pid_files.each { |x| kill_process(x) }
    end
  end
end