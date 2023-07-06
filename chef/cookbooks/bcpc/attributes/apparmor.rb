###############################################################################
# apparmor
###############################################################################

apparmor_package = 'apparmor_2.13.3-7ubuntu5.2_amd64.deb'
default['bcpc']['apparmor']['apparmor']['file'] = apparmor_package
default['bcpc']['apparmor']['apparmor']['source'] = "#{default['bcpc']['web_server']['url']}/#{apparmor_package}"
default['bcpc']['apparmor']['apparmor']['checksum'] = 'a377c3ac00ea9d008f55299ff97e88d7199ea127c2f70195ba506c8273cfa7c9'

libapparmor1_package = 'libapparmor1_2.13.3-7ubuntu5.2_amd64.deb'
default['bcpc']['apparmor']['libapparmor1']['file'] = libapparmor1_package
default['bcpc']['apparmor']['libapparmor1']['source'] = "#{default['bcpc']['web_server']['url']}/#{libapparmor1_package}"
default['bcpc']['apparmor']['libapparmor1']['checksum'] = 'ada0314841a62b200c96228b25ad0bfb7c4d6bf23906d4467ce2d8afb9f31606'
