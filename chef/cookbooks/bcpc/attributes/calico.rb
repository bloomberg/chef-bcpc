###############################################################################
# calico
###############################################################################

# calico apt repository
default['bcpc']['calico']['repo']['url'] =
 'http://ppa.launchpad.net/project-calico/calico-3.26/ubuntu'
default['bcpc']['calico']['repo']['key'] = 'calico/release.key'

# calicoctl
default['bcpc']['calico']['calicoctl']['remote']['file'] = 'calicoctl'
default['bcpc']['calico']['calicoctl']['remote']['source'] =
 "#{default['bcpc']['web_server']['url']}/calicoctl"
default['bcpc']['calico']['calicoctl']['remote']['checksum'] =
 '19ce069f121f9e245f785a7517521e20fe3294ce1add9d1b2bbcbb0a9b9de24e'

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
