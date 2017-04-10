###########################################
#
#  Cobbler configuration
#
###########################################

# list of kickstart templates to be loaded from cookbook templates
# (listing 'bcpc_ubuntu_host.preseed' here will look for a file
# 'cobbler.bcpc_ubuntu_host.preseed.erb', for example)
default['bcpc']['cobbler']['kickstarts'] = %w(
  bcpc_ubuntu_host.preseed
  bcpc_ubuntu_host_uefi.preseed
)

# hash of distributions in bcpc-binary-files to import into Cobbler
# iso_source can be either 'bcpc-binary-files' or 'uri',
# if uri will expect a URI to where to find the ISO, and
# the 'shasum' key must also be set to the SHA-256 hash of the ISO
default['bcpc']['cobbler']['distributions'] = {
  'ubuntu-14.04-mini' => {
    'arch'       => 'x86_64',
    'breed'      => 'ubuntu',
    'iso_source' => 'bcpc-binary-files',
    'os_version' => 'trusty',
    'source'     => 'ubuntu-14.04-mini.iso',
  }
}

# sample entry for a full ISO
#   'ubuntu-14.04.4-full' => {
#     'arch'       => 'x86_64',
#     'breed'      => 'ubuntu',
#     'iso_source' => 'uri',
#     'os_version' => 'trusty',
#     'shasum'     => '07e4bb5569814eab41fafac882ba127893e3ff0bdb7ec931c9b2d040e3e94e7a',
#     'source'     => 'http://10.0.100.2:8080/ubuntu-14.04.4-server-amd64.iso',
#   },

# hash that maps profile names to a particular kickstart and distribution
# (Cobbler will create the distribution name as distro-arch, e.g.
# ubuntu-14.04-mini-x86_64)
default['bcpc']['cobbler']['profiles'] = {
  'bcpc_host' => {
    'distro' => 'ubuntu-14.04-mini-x86_64',
    'kickstart' => 'bcpc_ubuntu_host.preseed',
  },
  'bcpc_host_uefi' => {
    'distro' => 'ubuntu-14.04-mini-x86_64',
    'kickstart' => 'bcpc_ubuntu_host_uefi.preseed'
  }
}


