###############################################################################
# calico/calicoctl
###############################################################################

default['bcpc']['calico']['repo']['enabled'] = true
default['bcpc']['calico']['repo']['url'] = "http://ppa.launchpad.net/project-calico/calico-3.1/ubuntu"

default['bcpc']['calico']['remote']['file'] = 'calicoctl'
default['bcpc']['calico']['remote']['source'] = "#{default['bcpc']['file_server']['url']}/calicoctl"
default['bcpc']['calico']['remote']['checksum'] = '62ae2334f62ca5e5501022845a885efdae8cd10cfbe40293a58e3d85d39bc120'
