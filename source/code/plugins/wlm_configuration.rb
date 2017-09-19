module WLM
  class Configuration
  
    require_relative 'oms_configuration'
    require_relative 'omslog'
    require_relative 'oms_common'
  
    @@configuration_loaded = false;
    @@config_data = nil;
    
    def self.load_wlm_discovery_configuration(wlm_conf_path)
      return true if @@configuration_loaded
      return false if !OMS::Configuration.test_onboard_file(wlm_conf_path)
      
      lines = IO.readlines(wlm_conf_path)
      if lines.size == 0
        OMS::Log.error_once("Config file #{wlm_conf_path} is empty")
        return false
      end

      @@config_data = Array.new
      lines.each do |line|
        params = line.strip.split(":")
        config_hash = Hash.new
        config_hash["object_name"] = params[0]
        config_hash["instance_regex"] = params[1]
        config_hash["counter_name_regex"] = params[2]
        config_data.push(config_hash)
      end
      
      @@configuration_loaded = true
      return true
    end # Method load_wlm_discovery_configuration
    
    def self.config_data
      @@config_data
    end
  end # Class Configuration
end #module WLM
