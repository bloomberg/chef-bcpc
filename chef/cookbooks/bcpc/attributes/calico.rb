###############################################################################
# calico/calicoctl
###############################################################################

default['bcpc']['calico']['repo']['enabled'] = true
default['bcpc']['calico']['repo']['url'] = 'http://ppa.launchpad.net/project-calico/calico-3.2/ubuntu'

default['bcpc']['calico']['remote']['file'] = 'calicoctl'
default['bcpc']['calico']['remote']['source'] = "#{default['bcpc']['file_server']['url']}/calicoctl"
default['bcpc']['calico']['remote']['checksum'] = '3396ee93361726eede85e3f86b256c80bf8d9d95e6ec37b6573fb44e7bf64e2f'
