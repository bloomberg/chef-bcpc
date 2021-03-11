###############################################################################
# rabbitmq
###############################################################################

# source rabbitmq from 3rd party apt repository
default['bcpc']['rabbitmq']['source']['repo']['enabled'] = false
default['bcpc']['rabbitmq']['source']['repo']['url'] = 'http://dl.bintray.com/rabbitmq/debian'

# source rabbitmq from a different distribution
default['bcpc']['rabbitmq']['source']['distribution']['enabled'] = true
default['bcpc']['rabbitmq']['source']['distribution']['name'] = 'bionic-backports'

# if changing this setting, you will need to reset Mnesia
# on all RabbitMQ nodes in the cluster
default['bcpc']['rabbitmq']['durable_queues'] = true

# ulimits for RabbitMQ server
default['bcpc']['rabbitmq']['ulimit']['nofile'] = 4096

# Heartbeat timeout to detect dead RabbitMQ brokers
default['bcpc']['rabbitmq']['heartbeat'] = 60
