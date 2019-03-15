###############################################################################
# calico
###############################################################################

# calico apt repository
default['bcpc']['calico']['repo']['url'] = 'http://ppa.launchpad.net/project-calico/calico-3.4/ubuntu'

# calicoctl
default['bcpc']['calico']['calicoctl']['remote']['file'] = 'calicoctl'
default['bcpc']['calico']['calicoctl']['remote']['source'] = "#{default['bcpc']['file_server']['url']}/calicoctl"
default['bcpc']['calico']['calicoctl']['remote']['checksum'] = '7017efab112a75ff7123ca0db62a52940e68bd6f1f2fe41ef08fe12dd4c89ca5'

# calico-felix
