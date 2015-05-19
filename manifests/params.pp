class appdynamics::params {
  if $::operatingsystemrelease =~ /^(\d+)/ {
    #$appd_version = "3.7.7-1799.el${1}"
    $appd_version = "3.7.10-1936.el${1}"
  } else {
    fail('couldn\'t figure out lsbmajdistrelease (facter bug workaround)')
  }
}
