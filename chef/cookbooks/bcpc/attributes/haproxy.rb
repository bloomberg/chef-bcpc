###############################################################################
#  haproxy
###############################################################################

# Installation-related configuration options
default['bcpc']['haproxy']['apt']['enabled'] = false
default['bcpc']['haproxy']['apt']['url'] = 'http://ppa.launchpad.net/vbernat/haproxy-1.8/ubuntu'

# QoS protection-related configuration options

# Whether QoS is enabled or not.
default['bcpc']['haproxy']['qos']['enabled'] = false

# The amount of time to wait for HTTP headers to be sent
default['bcpc']['haproxy']['qos']['http_request_timeout'] = '5s'

# The amount of time to wait for another HTTP request to be received
default['bcpc']['haproxy']['qos']['http_keep_alive_timeout'] = '10s'

# The maximum number of entries in the stick table
default['bcpc']['haproxy']['qos']['max_entries'] = '1m'

# Stick table entry expiration time
default['bcpc']['haproxy']['qos']['entry_expiration'] = '10m'

# The period across which the TCP connection rate of clients is measured
default['bcpc']['haproxy']['qos']['conn_rate_period'] = '120s'

# The period across which the HTTP request rate of clients is measured
default['bcpc']['haproxy']['qos']['http_req_rate_period'] = '120s'

# The period across which the HTTP error response rate of clients is measured
default['bcpc']['haproxy']['qos']['http_err_rate_period'] = '30s'

# Maximum number of concurrent connections allowed per client
default['bcpc']['haproxy']['qos']['conn_limit'] = 50

# The number of TCP connections allowed per client within conn_rate_period
default['bcpc']['haproxy']['qos']['conn_rate'] = 1200

# The number of HTTP requests allowed per client within http_req_rate_period
default['bcpc']['haproxy']['qos']['http_req_rate'] = 600

# The number of HTTP requests resulting in a 4xx error allowed per client
# within http_err_rate_period
default['bcpc']['haproxy']['qos']['http_err_rate'] = 30

# An array of CIDRs and/or IPs to exempt from QoS
default['bcpc']['haproxy']['qos']['exemptions'] = []

# SLO link returned in 429 responses
default['bcpc']['haproxy']['qos']['slo_url'] = nil
