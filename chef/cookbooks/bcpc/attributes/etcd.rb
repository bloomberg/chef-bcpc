###############################################################################
# etcd
###############################################################################

etcd_file = 'etcd-v3.3.10-linux-amd64.tar.gz'
default['bcpc']['etcd']['remote']['file'] = etcd_file
default['bcpc']['etcd']['remote']['source'] = "#{default['bcpc']['file_server']['url']}/#{etcd_file}"
default['bcpc']['etcd']['remote']['checksum'] = '1620a59150ec0a0124a65540e23891243feb2d9a628092fb1edcc23974724a45'

default['bcpc']['etcd']['ssl']['dir'] = '/etc/etcd/ssl'
default['bcpc']['etcd']['ca']['crt']['filepath'] = "#{default['bcpc']['etcd']['ssl']['dir']}/ca.pem"
default['bcpc']['etcd']['client']['crt']['filepath'] = "#{default['bcpc']['etcd']['ssl']['dir']}/client.pem"
default['bcpc']['etcd']['client']['key']['filepath'] = "#{default['bcpc']['etcd']['ssl']['dir']}/client-key.pem"
default['bcpc']['etcd']['server']['crt']['filepath'] = "#{default['bcpc']['etcd']['ssl']['dir']}/server.pem"
default['bcpc']['etcd']['server']['key']['filepath'] = "#{default['bcpc']['etcd']['ssl']['dir']}/server-key.pem"
