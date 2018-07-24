###############################################################################
# apt
###############################################################################

# go through proxy for apt packages
proxy = node['bcpc']['proxy']
default['bcpc']['apt']['proxy']['enabled'] = proxy['enabled']
default['bcpc']['apt']['proxies']['http'] = proxy['proxies']['http']
default['bcpc']['apt']['proxies']['https'] = proxy['proxies']['https']

# allow unauthenticated packages to be installed
default['bcpc']['apt']['allow_unauthenticated'] = false
