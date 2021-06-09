###############################################################################
# calico
###############################################################################

# calico apt repository
default['bcpc']['calico']['repo']['url'] =
 'http://ppa.launchpad.net/project-calico/calico-3.19/ubuntu'
default['bcpc']['calico']['repo']['key'] = 'calico/release.key'

# calicoctl
default['bcpc']['calico']['calicoctl']['remote']['file'] = 'calicoctl'
default['bcpc']['calico']['calicoctl']['remote']['source'] =
 "#{default['bcpc']['web_server']['url']}/calicoctl"
default['bcpc']['calico']['calicoctl']['remote']['checksum'] =
 'f49e9e8d25108f7f22d5a51c756b2fe40cbe36347ad297e31a767376172f2845'

# calico-felix
default['bcpc']['calico']['felix']['failsafe']['inbound'] = [
  'tcp:22',
  'tcp:179',
  'tcp:2379',
  'tcp:2380',
]

default['bcpc']['calico']['felix']['failsafe']['outbound'] = [
  'tcp:53',
  'udp:53',
  'udp:123',
  'tcp:179',
  'tcp:2379',
  'tcp:2380',
]
