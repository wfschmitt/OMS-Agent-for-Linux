#!/usr/local/bin/ruby

module Fluent

  class WLMDiscovery < Input
    Plugin.register_input('wlm_discovery', self)

    def initialize
      super
      require_relative 'oms_omi_lib'
      require_relative 'wlm_configuration'
    end

    config_param :config_path, :string
    config_param :discovery_time_file, :string
    config_param :omi_mapping_path, :string, :default => "/etc/opt/microsoft/omsagent/conf/omsagent.d/omi_mapping.json"
    
    @default_timeout = 30

    def configure (conf)
      super
      WLM::Configuration.load_wlm_discovery_configuration(@config_path)
    end

    def start
      @finished = false
      @condition = ConditionVariable.new
      @mutex = Mutex.new
      @thread = Thread.new(&method(:run_periodic))
    end

    def shutdown
      if @interval
        @mutex.synchronize {
          @finished = true
          @condition.signal
        }
        @thread.join
      end
      @omi_lib.disconnect
    end

    def enumerate
      discovery_data = WLM::Configuration.config_data
      discovery_data.each do |data|
        if(!@omi_lib)
          @omi_lib = OmiOms.new(data["object_name"], data["instance_regex"], data["counter_name_regex"], @omi_mapping_path)
        else
          @omi_lib.updateVars(data["object_name"], data["instance_regex"], data["counter_name_regex"], @omi_mapping_path)
        end
        time = Time.now.to_f
        wrapper = @omi_lib.enumerate(time, "WLM_DISCOVERY_BLOB", "WorkloadMonitoring")
        router.emit("oms.wlm.discovery", time, wrapper) if wrapper
      end
      update_discovery_time(Time.now.to_i)
    end

    def run_periodic
      timeout_value = @default_timeout
      last_discovery_time = Time.at(get_last_discovery_time.to_i)
      if(last_discovery_time.to_i > 0)
        next_discovery_time = last_discovery_time + @default_timeout
        current_time = Time.now
        if(current_time >= next_discovery_time)
          enumerate
        else
          timeout_value = next_discovery_time - current_time
        end
      else
        enumerate
      end
      @mutex.lock
      done = @finished
      until done
        @condition.wait(@mutex, timeout_value)
        timeout = @default_timeout
        done = @finished
        @mutex.unlock
        if !done
          enumerate
        end
        @mutex.lock
      end
      @mutex.unlock
    end
    
    def update_discovery_time(time)
      begin
        time_file = File.open(@discovery_time_file, "w")
        time_file.write(time.to_s)
      rescue => e
        $log.info "Error updating last discovery time #{e}"
      ensure
        time_file.close unless time_file.nil?
      end
    end
    
    def get_last_discovery_time()
      begin
        last_discovery_time = File.open(@discovery_time_file, &:readline)
        return last_discovery_time.strip()
      rescue => e
        $log.debug "Error reading last discovery time #{e}"
        return nil
      end
    end

  end # OMS_OMI_Input

end # module
