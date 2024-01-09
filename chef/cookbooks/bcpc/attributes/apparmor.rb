###############################################################################
# apparmor
###############################################################################

apparmor_package = 'apparmor_2.13.3-7ubuntu5.3_amd64.deb'
default['bcpc']['apparmor']['apparmor']['file'] = apparmor_package
default['bcpc']['apparmor']['apparmor']['source'] = "#{default['bcpc']['web_server']['url']}/#{apparmor_package}"
default['bcpc']['apparmor']['apparmor']['checksum'] = '9d8db85f466edc2a77b42e9d3f77f7c481d9122b82dcbffa97a56850f00a5646'

libapparmor1_package = 'libapparmor1_2.13.3-7ubuntu5.3_amd64.deb'
default['bcpc']['apparmor']['libapparmor1']['file'] = libapparmor1_package
default['bcpc']['apparmor']['libapparmor1']['source'] = "#{default['bcpc']['web_server']['url']}/#{libapparmor1_package}"
default['bcpc']['apparmor']['libapparmor1']['checksum'] = 'f96b92e473863bb1d55cdd0b0c68a47871d04092f3a86d6a49bbf1dc3ba9ae32'
