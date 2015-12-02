chef_server_url 'https://localhost/organizations/bcpc'
node_name 'admin'
client_key '/etc/opscode/admin.pem'
# :verify_none should be okay for talking to localhost chef server
ssl_verify_mode :verify_none
