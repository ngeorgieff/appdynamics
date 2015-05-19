appd_facts = {}
hostnum = `hostname -s`.chomp.gsub(/^[^0-9]+/,'')
igenv = Facter.value('environment').to_s.chomp.upcase
live_or_demo = Facter.value('live_or_demo').to_s.chomp.upcase

# Lookup version installed
adrpm = `rpm -qa | grep AppDynamicsAgents`.to_s.gsub(/^AppDynamicsAgents-(.*)$/,'\1') 
if (adrpm)
  Facter.add(:ad_version) do
    setcode do
      adrpm
    end
  end
end

# Read in values from the /etc/sysconfig/appdynamics file
if (File.exist?('/etc/sysconfig/appdynamics'))
  File.open('/etc/sysconfig/appdynamics').each {|line|
    setting = line.chomp.split('=')
    if (setting[0] && setting[1])
      appd_facts[setting[0]] = setting[1]
    end
  }

  if (appd_facts['AD_tierName'] && hostnum && igenv )
    appd_facts['AD_hostId'] = "#{igenv}-#{appd_facts['AD_tierName']}-#{hostnum}"
  end
 
  if (appd_facts['AD_applicationName'] && igenv)
    if (igenv =~ /^PROD[12]/)
      appd_facts['AD_applicationName'] = "#{live_or_demo}-#{appd_facts['AD_applicationName']}"
    else
      appd_facts['AD_applicationName'] = "#{igenv}-#{appd_facts['AD_applicationName']}"
    end
  end

  numrunning = 0
  tiers = {}
  nodes = []

  Dir.foreach("/proc"){ |file|
    next if file =~ /\D/
    begin 
      cmdline = IO.read("/proc/#{file}/cmdline").tr("\000", ' ').strip
      if cmdline =~ /-Dappdynamics.agent.tierName=([^\s]+)/
        tiers[$1] = true
      end
      if cmdline =~ /-Dappdynamics.agent.nodeName=([^\s]+)/
        nodes << $1
        numrunning += 1
      end
    rescue
    end
  }

  appd_facts['AD_javaagents_tiers'] = tiers.keys.sort.join(",")
  appd_facts['AD_javaagents_nodes'] = nodes.sort.join(",")

  if numrunning >= 1
    appd_facts['AD_javaagents_running'] = numrunning
  end 

  # output the facts
  appd_facts.each_pair {|k,v|
    Facter.add(k) do
      setcode do
        v
      end
    end	
  }

end
