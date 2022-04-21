###############################################################################
# calico
###############################################################################

# calico apt repository
default['bcpc']['calico']['repo']['url'] =
 'http://ppa.launchpad.net/project-calico/calico-3.22/ubuntu'
default['bcpc']['calico']['repo']['key'] = 'calico/release.key'

# calicoctl
default['bcpc']['calico']['calicoctl']['remote']['file'] = 'calicoctl'
default['bcpc']['calico']['calicoctl']['remote']['source'] =
 "#{default['bcpc']['web_server']['url']}/calicoctl"
default['bcpc']['calico']['calicoctl']['remote']['checksum'] =
 '2608fe464b50019e4ade388142f194463e351013ec81da21b111307411865a81'

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
