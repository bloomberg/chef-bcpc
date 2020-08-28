###############################################################################
# calico
###############################################################################

# calico apt repository
default['bcpc']['calico']['repo']['url'] =
 'http://ppa.launchpad.net/project-calico/calico-3.15-python2/ubuntu'
default['bcpc']['calico']['repo']['key'] = 'calico/release.key'

# calicoctl
default['bcpc']['calico']['calicoctl']['remote']['file'] = 'calicoctl'
default['bcpc']['calico']['calicoctl']['remote']['source'] =
 "#{default['bcpc']['web_server']['url']}/calicoctl"
default['bcpc']['calico']['calicoctl']['remote']['checksum'] =
 '4600d5d7f08ed9cf479fc8fa87518dbbca32a473d0a4a212cfecb610c18216aa'

# calico-felix
#
# Although neither VXLAN or IP in IP encapsulation is used here by Calico,
# the change in https://github.com/projectcalico/felix/pull/2063 to address
# a security issue (see Tigera Technical Advisory TTA-2019-002) prevents
# instances from using VXLAN or IP in IP encapsulation themselves. As a
# work-around for the VXLAN case, an alternate port can be set for Calico
# to "use" which allows the use of the standard VXLAN port by instances
# within OpenStack.
default['bcpc']['calico']['calico-felix']['vxlan_port'] = 9
