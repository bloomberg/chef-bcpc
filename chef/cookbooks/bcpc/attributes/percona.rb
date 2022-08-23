###############################################################################
# Percona related values
###############################################################################

# Repo variables
default['bcpc']['percona']['repo']['enabled'] = true
default['bcpc']['percona']['repo']['url'] = 'http://repo.percona.com/pxc-80/apt'
default['bcpc']['percona']['repo']['key'] = 'percona/release.key'

default['bcpc']['percona-tools']['repo']['enabled'] = true
default['bcpc']['percona-tools']['repo']['url'] = 'http://repo.percona.com/tools/apt'
default['bcpc']['percona-tools']['repo']['key'] = 'percona/release.key'
