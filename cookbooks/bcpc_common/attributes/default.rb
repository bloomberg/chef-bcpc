###########################################
#
#  bcpc_common cookbook configuration
#
###########################################

###########################################
#
# Package settings
#
###########################################

default['bcpc_common']['packages']['convenience'] = %w(
  emacs24-nox
  logtail
  patch
  sshpass
  vim
)
default['bcpc_common']['packages']['net_troubleshooting'] = %w(
  bmon
  conntrack
  curl
  dhcpdump
  ethtool
  iperf
  nmap
  tshark
)
default['bcpc_common']['packages']['io_troubleshooting'] = %w(
  bc
  fio
  iotop
)
default['bcpc_common']['packages']['sys_troubleshooting'] = %w(
  htop
  linux-tools-common
  sosreport
  sysstat
)
default['bcpc_common']['packages']['to_remove'] = %w(
  powernap
)

# apt-get update on each Chef run
default['apt']['compile_time_update'] = true

# These will enable automatic dist-upgrade/upgrade at the end of a Chef run
default['bcpc']['enabled']['apt_dist_upgrade'] = false
default['bcpc']['enabled']['apt_upgrade'] = false

# Toggle to enable apport for debugging process crashes
default['bcpc']['enabled']['apport'] = true

###########################################
#
# CPU governor settings
#
###########################################

# Available options:
# =< 3.13: conservative, ondemand, userspace, powersave, performance
# > 3.13: performance, powersave
# Review documentation at https://www.kernel.org/doc/Documentation/cpu-freq/governors.txt

# recommended to leave this off so it does not conflict with the provider
default['bcpc']['enabled']['cpufrequtils'] = false

default['bcpc']['cpupower']['governor'] = 'ondemand'
default['bcpc']['cpupower']['ondemand_ignore_nice_load'] = nil
default['bcpc']['cpupower']['ondemand_io_is_busy'] = nil
default['bcpc']['cpupower']['ondemand_powersave_bias'] = nil
default['bcpc']['cpupower']['ondemand_sampling_down_factor'] = nil
default['bcpc']['cpupower']['ondemand_sampling_rate'] = nil
default['bcpc']['cpupower']['ondemand_up_threshold'] = nil

###########################################
#
#  Getty settings
#
###########################################
default['bcpc']['getty']['ttys'] = %w( ttyS0 ttyS1 )
