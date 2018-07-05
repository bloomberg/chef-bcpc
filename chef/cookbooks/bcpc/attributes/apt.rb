###############################################################################
# apt
###############################################################################

# go through proxy for apt packages
default['bcpc']['apt']['proxy']['enabled'] = node['bcpc']['proxy']['enabled']
default['bcpc']['apt']['proxies']['http'] = node['bcpc']['proxy']['proxies']['http']
default['bcpc']['apt']['proxies']['https'] = node['bcpc']['proxy']['proxies']['https']

# allow unauthenticated packages to be installed
default['bcpc']['apt']['allow_unauthenticated'] = false
