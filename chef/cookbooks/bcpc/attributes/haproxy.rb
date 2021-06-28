###############################################################################
#  haproxy
###############################################################################

# Installation-related configuration options
default['bcpc']['haproxy']['repo']['enabled'] = false
default['bcpc']['haproxy']['repo']['url'] = 'http://ppa.launchpad.net/vbernat/haproxy-1.8/ubuntu'
default['bcpc']['haproxy']['repo']['key'] = 'haproxy/haproxy.key'

# QoS protection-related configuration options

# Whether QoS is enabled or not.
default['bcpc']['haproxy']['qos']['enabled'] = false

# The amount of time to wait for HTTP headers to be sent (timeout http-request)
# and the amount of time to wait for a new HTTP request to appear (timeout
# http-keep-alive).
# NOTE: If `http-keep-alive` is exceeded client TCP connections are closed
# silently.
# NOTE: It is **highly** recommended that `http-keep-alive` not be set to 5s.
# If set to 5s there is the possibility of a race condition when the --wait
# option of the Openstack client is used, which periodically executes API
# requests every 5 seconds, that results in client TCP connections being closed
# unexpectedly.
default['bcpc']['haproxy']['qos']['http_request_timeout'] = '10s'

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

# The value of the Retry-After header specified in 429 responses
default['bcpc']['haproxy']['qos']['retry_after'] = 5
