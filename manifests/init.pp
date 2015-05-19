## AppDynamics agent provisioning
## 
## Nikolay Georgieff (c) 2014
##
## 

class appdynamics (
  $appd_user            = 'appdyn',
  $appd_network         = 'testNetwork',
  $appd_version         = '3.8.4',
  $appd_home            = '/opt/AppDyamics',
  $AppServerAgent_url   = 'https://repo.it.company.com/artifactory/its-appdynamics/AppDynamics/AppServerAgent',
  $MachineAgent_url     = 'https://repo.it.company.com/artifactory/its-appdynamics/AppDynamics/MachineAgent',
  $unique_hostid        = 'server_hostname1',
  $application          = 'testApp',
  $skip_AppServerAgent  = 'false',
) inherits appdynamics::params {
  if !$appd_version {
    fail('AppDynamics version parameter must not be empty (eg. 3.8.4)')
  }

  if $skip_AppServerAgent == 'true' {
    exec { 'Skip_AppServerAgent_installer':
      path    => [ '/bin', '/usr/bin' ],
      command => "mkdir -p ${appd_home}/AppServerAgent/${appd_version}/conf && touch ${appd_home}/AppServerAgent/${appd_version}/AppServerAgent-${appd_version}.installed ",
      unless  => "test -f ${appd_home}/AppServerAgent/${appd_version}/AppServerAgent-${appd_version}.installed",
    }
  }
  else {
    exec { "Cleanup_AppServerAgent_installer":
      path    => [ '/bin', '/usr/bin' ],
      command => "rm -rf ${appd_home}/AppServerAgent/${appd_version}/",
      unless => "test -d ${appd_home}/AppServerAgent/${appd_version}/lib/",
    }
  }


  #$appd_controller      = hiera('appd_controller')
  #$appd_controller_port = hiera('appd_controller_port')
  #$appd_maxMetrics      = hiera('appd_maxMetrics')

  #if !$application {
  #  $appd_app_name = hiera('appd_app_name')
  #} else {
  #  $appd_app_name = $application
  #}
  
  # Install all required packages 
  package { 'wget': ensure => 'present' }
  package { 'unzip': ensure =>  'present' }

  # Create AppDynamics group
  group { $appd_user:
    ensure => 'present',
    gid    => 7171,
  }
  
  # Create AppDynamics user
  user { $appd_user:
    ensure     => 'present',
    uid        => 7171,
    managehome => true,
    home       => "/home/${appd_user}",
    gid        => 7171,
    require    => Group[$appd_user],
  }
  
  # Create AppDynamics home directory
  exec { 'mkdir_appd_home':
    path    => [ '/bin', '/usr/bin' ],
    command => "mkdir -p ${appd_home}/AppServerAgent/${appd_version} && mkdir -p ${appd_home}/MachineAgent/${appd_version}",
    unless  => "test -d ${appd_home}/AppServerAgent/${appd_version} && test -d ${appd_home}/MachineAgent/${appd_version}",
  }

  # Create Log directory
  file { '/var/log/AppDynamics':
    ensure => 'directory',
    owner  => $appd_user,
    group  => $appd_user,
    mode   => '0770',
  }

  # Get AppDynamics agents
  exec { 'get_AppServerAgent_installer':
    path    => [ '/bin', '/usr/bin' ],
    cwd     => "${appd_home}/AppServerAgent/${appd_version}",
    creates => "${appd_home}/AppServerAgent/${appd_version}/AppServerAgent-${appd_version}.zip",
    command => "/usr/bin/wget -c \"${AppServerAgent_url}/${appd_version}/AppServerAgent-${appd_version}.zip\" -O AppServerAgent-${appd_version}.zip",
    timeout => 600,
    unless  => "test -f ${appd_home}/AppServerAgent/${appd_version}/AppServerAgent-${appd_version}.installed",
    require => [ Package['wget'], Exec['mkdir_appd_home'] ],
  }

  exec { 'get_MachineAgent_installer':
    path    => [ '/bin', '/usr/bin' ],
    cwd     => "${appd_home}/MachineAgent/${appd_version}",
    creates => "${appd_home}/MachineAgent/${appd_version}/MachineAgent-${appd_version}.zip",
    command => "/usr/bin/wget -c \"${MachineAgent_url}/${appd_version}/MachineAgent-${appd_version}.zip\" -O MachineAgent-${appd_version}.zip",
    timeout => 600,
    unless  => "test -f ${appd_home}/MachineAgent/${appd_version}/MachineAgent-${appd_version}.installed",
    require => Exec['get_AppServerAgent_installer'],
  }
  
  # Extract AppDynamics Agents
  exec { 'extract_AppServerAgent':
    path    => [ '/bin', '/usr/bin' ],
    cwd     => "${appd_home}/AppServerAgent/${appd_version}",
    command => "unzip AppServerAgent-${appd_version}.zip && touch AppServerAgent-${appd_version}.installed && rm -f AppServerAgent-${appd_version}.zip",
    unless  => "test -f ${appd_home}/AppServerAgent/${appd_version}/AppServerAgent-${appd_version}.installed",
    require => [ Exec['get_AppServerAgent_installer'], Package['unzip'] ],
  }
  exec { 'extract_MachineAgent':
    path    => [ '/bin', '/usr/bin' ],
    cwd     => "${appd_home}/MachineAgent/${appd_version}",
    command => "unzip MachineAgent-${appd_version}.zip && touch MachineAgent-${appd_version}.installed && rm -f MachineAgent-${appd_version}.zip",
    unless  => "test -f ${appd_home}/MachineAgent/${appd_version}/MachineAgent-${appd_version}.installed",
    require => [ Exec['get_MachineAgent_installer'], Package['unzip'] ],
  }

  # Add Symbolic links to current version of agents
  file { "${appd_home}/AppServerAgent/Current":
    ensure  => link,
    target  => "${appd_home}/AppServerAgent/${appd_version}",
    force   => true,
  }
  
  file { "${appd_home}/MachineAgent/Current":
    ensure  => link,
    target  => "${appd_home}/MachineAgent/${appd_version}",
    force   => true,
  }
  
  # Configure controller-info.xml
  file { "${appd_home}/AppServerAgent/${appd_version}/conf/controller-info.xml":
    ensure  => present,
    owner   => $appd_user,
    group   => $appd_user,
    mode    => '0640',
    content => template('appdynamics/AppServerAgent/controller-info.xml.erb'),
  }
  
  file { "${appd_home}/MachineAgent/${appd_version}/conf/controller-info.xml":
      ensure  => present,
      owner   => $appd_user,
      group   => $appd_user,
      mode    => '0640',
      content => template('appdynamics/MachineAgent/controller-info.xml.erb'),
    }
  
  # Configure machineagent init script 
  file { "/etc/init.d/machineagentd":
      ensure  => present,
      owner   => root,
      group   => root,
      mode    => '0755',
      content => template('appdynamics/MachineAgent/machineagentd.erb'),
      require => File["${appd_home}/MachineAgent/${appd_version}/conf/controller-info.xml"],
      notify  => Service['machineagentd'],
  }
  
  # Configure and enable machineagent service
  service { 'machineagentd':
    ensure => 'running',
    enable => 'true',
  }


  # Set Resource Ordering
  File['/var/log/AppDynamics'] -> Exec['mkdir_appd_home'] -> Exec['extract_MachineAgent'] -> Exec['extract_AppServerAgent'] -> File["${appd_home}/AppServerAgent/Current"] -> File["${appd_home}/MachineAgent/Current"] -> File["${appd_home}/AppServerAgent/${appd_version}/conf/controller-info.xml"] -> File["${appd_home}/MachineAgent/${appd_version}/conf/controller-info.xml"]

}
