###########################################
#
#  General configuration for this cluster
#
###########################################
default['bcpc']['country'] = "US"
default['bcpc']['state'] = "NY"
default['bcpc']['location'] = "New York"
default['bcpc']['organization'] = "Bloomberg"
default['bcpc']['openstack_release'] = "kilo"
# Can be "updates" or "proposed"
default['bcpc']['openstack_branch'] = "proposed"
# Should be kvm (or qemu if testing in VMs that don't support VT-x)
default['bcpc']['virt_type'] = "kvm"
# Define the kernel to be installed. By default, track latest LTS kernel
default['bcpc']['preseed']['kernel'] = "linux-image-generic-lts-trusty"
# ulimits for libvirt-bin
default['bcpc']['libvirt-bin']['ulimit']['nofile'] = 4096
# Region name for this cluster
default['bcpc']['region_name'] = node.chef_environment
# Domain name for this cluster (used in many configs)
default['bcpc']['domain_name'] = "bcpc.example.com"
# Key if Cobalt+VMS is to be used
default['bcpc']['vms_key'] = nil

###########################################
#
# Package versions
#
###########################################
default['bcpc']['elasticsearch']['version'] = '1.5.1'
default['bcpc']['ceph']['version'] = '0.94.2-1trusty'
default['bcpc']['ceph']['version_number'] = '0.94.2'
# Ceph.com version number '0.94.2-1trusty'
# Ubuntu cloud version number '0.94.1-0ubuntu1~cloud0'
default['bcpc']['erlang']['version'] = '1:17.5.3'
default['bcpc']['haproxy']['version'] = '1.5.12-1ppa1~trusty'
default['bcpc']['kibana']['version'] = '4.0.2'
default['bcpc']['rabbitmq']['version'] = '3.5.3-1'

###########################################
#
#  Flags to enable/disable BCPC cluster features
#
###########################################
# This will enable elasticsearch & kibana on head nodes and fluentd on all nodes
default['bcpc']['enabled']['logging'] = true
# This will enable graphite web and carbon on head nodes and diamond on all nodes
default['bcpc']['enabled']['metrics'] = true
# This will enable zabbix server on head nodes and zabbix agent on all nodes
default['bcpc']['enabled']['monitoring'] = true
# This will enable powerdns on head nodes
default['bcpc']['enabled']['dns'] = true
# This will enable iptables firewall on all nodes
default['bcpc']['enabled']['host_firewall'] = true
# This will enable of encryption of the chef data bag
default['bcpc']['enabled']['encrypt_data_bag'] = false
# This will enable auto-upgrades on all nodes (not recommended for stability)
default['bcpc']['enabled']['apt_upgrade'] = false
# This will enable running apt-get update at the start of every Chef run
default['bcpc']['enabled']['always_update_package_lists'] = true
# This will enable the extra healthchecks for keepalived (VIP management)
default['bcpc']['enabled']['keepalived_checks'] = true
# This will enable the networking test scripts
default['bcpc']['enabled']['network_tests'] = true
# This will enable httpd disk caching for radosgw in apache
default['bcpc']['enabled']['radosgw_cache'] = false
# This will enable using TPM-based hwrngd
default['bcpc']['enabled']['tpm'] = false
# This will block VMs from talking to the management network
default['bcpc']['enabled']['secure_fixed_networks'] = true

# If radosgw_cache is enabled, default to 20MB max file size
default['bcpc']['radosgw']['cache_max_file_size'] = 20000000

###########################################
#
#  Host-specific defaults for the cluster
#
###########################################
default['bcpc']['ceph']['hdd_disks'] = ["sdb", "sdc"]
default['bcpc']['ceph']['ssd_disks'] = ["sdd", "sde"]
default['bcpc']['ceph']['enabled_pools'] = ["ssd", "hdd"]
default['bcpc']['management']['interface'] = "eth0"
default['bcpc']['storage']['interface'] = "eth1"
default['bcpc']['floating']['interface'] = "eth2"
default['bcpc']['fixed']['vlan_interface'] = node['bcpc']['floating']['interface']

###########################################
#
#  Ceph settings for the cluster
#
###########################################
# To use apache instead of civetweb, make the following value anything but 'civetweb'
default['bcpc']['ceph']['frontend'] = "civetweb"
default['bcpc']['ceph']['chooseleaf'] = "rack"
default['bcpc']['ceph']['pgp_auto_adjust'] = false
# Need to review...
default['bcpc']['ceph']['pgs_per_node'] = 1024
# Journal size could be 10GB or higher in some cases
default['bcpc']['ceph']['journal_size'] = 2048
# The 'portion' parameters should add up to ~100 across all pools
default['bcpc']['ceph']['default']['replicas'] = 3
default['bcpc']['ceph']['default']['type'] = 'hdd'
default['bcpc']['ceph']['rgw']['replicas'] = 3
default['bcpc']['ceph']['rgw']['portion'] = 33
default['bcpc']['ceph']['rgw']['type'] = 'hdd'
default['bcpc']['ceph']['images']['replicas'] = 3
default['bcpc']['ceph']['images']['portion'] = 33
# Set images to hdd instead of sdd
default['bcpc']['ceph']['images']['type'] = 'hdd'
default['bcpc']['ceph']['images']['name'] = "images"
default['bcpc']['ceph']['volumes']['replicas'] = 3
default['bcpc']['ceph']['volumes']['portion'] = 33
default['bcpc']['ceph']['volumes']['name'] = "volumes"
# Created a new pool for VMs and set type to ssd
default['bcpc']['ceph']['vms']['replicas'] = 3
default['bcpc']['ceph']['vms']['portion'] = 33
default['bcpc']['ceph']['vms']['type'] = 'ssd'
default['bcpc']['ceph']['vms']['name'] = "vms"

# Begin cobalt - not used in cluster
default['bcpc']['ceph']['vms_disk']['replicas'] = 3
default['bcpc']['ceph']['vms_disk']['portion'] = 10
default['bcpc']['ceph']['vms_disk']['type'] = 'ssd'
default['bcpc']['ceph']['vms_disk']['name'] = "vmsdisk"
default['bcpc']['ceph']['vms_mem']['replicas'] = 3
default['bcpc']['ceph']['vms_mem']['portion'] = 10
default['bcpc']['ceph']['vms_mem']['type'] = 'ssd'
default['bcpc']['ceph']['vms_mem']['name'] = "vmsmem"
# End cobalt

# Ruleset for CRUSH map
default['bcpc']['ceph']['ssd']['ruleset'] = 1
default['bcpc']['ceph']['hdd']['ruleset'] = 2

# If you are about to make a big change to the ceph cluster
# setting to true will reduce the load form the resulting
# ceph rebalance and keep things operational. 
# See wiki for further details. 
default['bcpc']['ceph']['rebalance'] = false

# Set the default niceness of Ceph OSD and monitor processes
default['bcpc']['ceph']['osd_niceness'] = -10
default['bcpc']['ceph']['mon_niceness'] = -10

###########################################
#
# RabbitMQ settings
#
###########################################
# if changing this setting, you will need to reset Mnesia
# on all RabbitMQ nodes in the cluster
default['bcpc']['rabbitmq']['durable_queues'] = true

###########################################
#
#  Network settings for the cluster
#
###########################################
default['bcpc']['management']['vip'] = "10.17.1.15"
default['bcpc']['management']['netmask'] = "255.255.255.0"
default['bcpc']['management']['cidr'] = "10.17.1.0/24"
default['bcpc']['management']['gateway'] = "10.17.1.1"
default['bcpc']['management']['interface'] = nil
default['bcpc']['management']['monitoring']['vip'] = "10.17.1.16"
# if 'interface' is a VLAN interface, specifying a parent allows MTUs
# to be set properly
default['bcpc']['management']['interface-parent'] = nil

default['bcpc']['metadata']['ip'] = "169.254.169.254"

default['bcpc']['storage']['netmask'] = "255.255.255.0"
default['bcpc']['storage']['cidr'] = "100.100.0.0/24"
default['bcpc']['storage']['gateway'] = "100.100.0.1"
default['bcpc']['storage']['interface'] = nil
# if 'interface' is a VLAN interface, specifying a parent allows MTUs
# to be set properly
default['bcpc']['storage']['interface-parent'] = nil

default['bcpc']['floating']['vip'] = "192.168.43.15"
default['bcpc']['floating']['netmask'] = "255.255.255.0"
default['bcpc']['floating']['cidr'] = "192.168.43.0/24"
default['bcpc']['floating']['gateway'] = "192.168.43.2"
default['bcpc']['floating']['available_subnet'] = "192.168.43.128/25"
default['bcpc']['floating']['interface'] = nil
# if 'interface' is a VLAN interface, specifying a parent allows MTUs
# to be set properly
default['bcpc']['floating']['interface-parent'] = nil

default['bcpc']['fixed']['cidr'] = "1.127.0.0/16"
default['bcpc']['fixed']['vlan_start'] = "1000"
default['bcpc']['fixed']['num_networks'] = "100"
default['bcpc']['fixed']['network_size'] = "256"
default['bcpc']['fixed']['dhcp_lease_time'] = "120"

default['bcpc']['ntp_servers'] = ["pool.ntp.org"]
default['bcpc']['dns_servers'] = ["8.8.8.8", "8.8.4.4"]

###########################################
#
#  Repos for things we rely on
#
###########################################
default['bcpc']['repos']['rabbitmq'] = "http://www.rabbitmq.com/debian"
default['bcpc']['repos']['mysql'] = "http://repo.percona.com/apt"
default['bcpc']['repos']['haproxy'] = "http://ppa.launchpad.net/vbernat/haproxy-1.5/ubuntu"
default['bcpc']['repos']['openstack'] = "http://ubuntu-cloud.archive.canonical.com/ubuntu"
default['bcpc']['repos']['hwraid'] = "http://hwraid.le-vert.net/ubuntu"
# there is no trusty repo for fluentd from this provider
#default['bcpc']['repos']['fluentd'] = "http://packages.treasure-data.com/#{node['lsb']['codename']}"
default['bcpc']['repos']['fluentd'] = "http://packages.treasure-data.com/precise"
default['bcpc']['repos']['gridcentric'] = "http://downloads.gridcentric.com/packages/%s/%s/ubuntu"
default['bcpc']['repos']['elasticsearch'] = "http://packages.elasticsearch.org/elasticsearch/1.5/debian"
default['bcpc']['repos']['erlang'] = "http://packages.erlang-solutions.com/ubuntu"
default['bcpc']['repos']['ceph'] = "http://ceph.com/debian-hammer"

###########################################
#
# [Optional] If using apt-mirror to pull down repos, we use these settings.
#
###########################################
# Note - us.archive.ubuntu.com tends to rate-limit pretty hard.
# If you are on East Coast US, we recommend Columbia University in env file:
# "mirror" : {
#  "ubuntu": "mirror.cc.columbia.edu/pub/linux/ubuntu/archive"
# }
# For a complete list of Ubuntu mirrors, please see:
# https://launchpad.net/ubuntu/+archivemirrors
default['bcpc']['mirror']['ubuntu'] = "us.archive.ubuntu.com/ubuntu"
default['bcpc']['mirror']['ubuntu-dist'] = ['trusty']
default['bcpc']['mirror']['ceph-dist'] = ['hammer']
default['bcpc']['mirror']['os-dist'] = ['kilo']
default['bcpc']['mirror']['elasticsearch-dist'] = '1.5'

###########################################
#
#  Default names for db's, pools, and users
#
###########################################
default['bcpc']['dbname']['nova'] = "nova"
default['bcpc']['dbname']['cinder'] = "cinder"
default['bcpc']['dbname']['glance'] = "glance"
default['bcpc']['dbname']['horizon'] = "horizon"
default['bcpc']['dbname']['keystone'] = "keystone"
default['bcpc']['dbname']['heat'] = "heat"
default['bcpc']['dbname']['ceilometer'] = "ceilometer"
default['bcpc']['dbname']['graphite'] = "graphite"
default['bcpc']['dbname']['pdns'] = "pdns"
default['bcpc']['dbname']['zabbix'] = "zabbix"

default['bcpc']['admin_tenant'] = "AdminTenant"
default['bcpc']['admin_role'] = "Admin"
default['bcpc']['member_role'] = "Member"
default['bcpc']['admin_email'] = "admin@localhost.com"

default['bcpc']['zabbix']['user'] = "zabbix"
default['bcpc']['zabbix']['group'] = "adm"

# General ports for both Apache and Civetweb (no ssl for civetweb at this time)
default['bcpc']['ports']['radosgw'] = 8088
default['bcpc']['ports']['radosgw_https'] = 443
default['bcpc']['ports']['civetweb']['radosgw'] = 8088
# Apache - Leave until Apache is removed
default['bcpc']['ports']['apache']['radosgw'] = 80
default['bcpc']['ports']['apache']['radosgw_https'] = 443

default['bcpc']['ports']['haproxy']['radosgw'] = 80
default['bcpc']['ports']['haproxy']['radosgw_https'] = 443

# Can be set to 'http' or 'https'
default['bcpc']['protocol']['keystone'] = "https"
default['bcpc']['protocol']['glance'] = "https"
default['bcpc']['protocol']['nova'] = "https"
default['bcpc']['protocol']['cinder'] = "https"
default['bcpc']['protocol']['heat'] = "https"

###########################################
#
#  Horizon Settings
#
###########################################
#
# List panels to remove from the Horizon interface here
# (if the last panel in a group is removed, the group will also be removed)
default['bcpc']['horizon']['disable_panels'] = ['containers']

###########################################
#
#  Keystone Settings
#
###########################################
#
# Eventlet server is deprecated in Kilo, so by default we
# serve Keystone via Apache now.
default['bcpc']['keystone']['eventlet_server'] = false
# Turn caching via memcached on or off.
default['bcpc']['keystone']['enable_caching'] = true
# Enable debug logging (also caching debug logging).
default['bcpc']['keystone']['debug'] = false
# Enable verbose logging.
default['bcpc']['keystone']['verbose'] = false
# Set the timeout for how long we will wait for Keystone to become operational
# before failing (configures timeout on the wait-for-keystone-to-be-operational
# spinlock guard).
default['bcpc']['keystone']['wait_for_keystone_timeout'] = 120
# This can be either 'sql' or 'ldap' to either store identities
# in the mysql DB or the LDAP server
default['bcpc']['keystone']['backend'] = 'sql'
default['bcpc']['ldap']['admin_user'] = nil
default['bcpc']['ldap']['admin_pass'] = nil
default['bcpc']['ldap']['config'] = {}

###########################################
#
#  Keystone policy Settings
#
###########################################
default['bcpc']['keystone']['policy'] = {
  "admin_required" => "role:admin or is_admin:1",
  "service_role" => "role:service",
  "service_or_admin" => "rule:admin_required or rule:service_role",
  "owner" => "user_id:%(user_id)s",
  "admin_or_owner" => "rule:admin_required or rule:owner",
  "token_subject" => "user_id:%(target.token.user_id)s",
  "admin_or_token_subject" => "rule:admin_required or rule:token_subject",

  "default" => "rule:admin_required",

  "identity:get_region" => "",
  "identity:list_regions" => "",
  "identity:create_region" => "rule:admin_required",
  "identity:update_region" => "rule:admin_required",
  "identity:delete_region" => "rule:admin_required",

  "identity:get_service" => "rule:admin_required",
  "identity:list_services" => "rule:admin_required",
  "identity:create_service" => "rule:admin_required",
  "identity:update_service" => "rule:admin_required",
  "identity:delete_service" => "rule:admin_required",

  "identity:get_endpoint" => "rule:admin_required",
  "identity:list_endpoints" => "rule:admin_required",
  "identity:create_endpoint" => "rule:admin_required",
  "identity:update_endpoint" => "rule:admin_required",
  "identity:delete_endpoint" => "rule:admin_required",

  "identity:get_domain" => "rule:admin_required",
  "identity:list_domains" => "rule:admin_required",
  "identity:create_domain" => "rule:admin_required",
  "identity:update_domain" => "rule:admin_required",
  "identity:delete_domain" => "rule:admin_required",

  "identity:get_project" => "rule:admin_required",
  "identity:list_projects" => "rule:admin_required",
  "identity:list_user_projects" => "rule:admin_or_owner",
  "identity:create_project" => "rule:admin_required",
  "identity:update_project" => "rule:admin_required",
  "identity:delete_project" => "rule:admin_required",

  "identity:get_user" => "rule:admin_required",
  "identity:list_users" => "rule:admin_required",
  "identity:create_user" => "rule:admin_required",
  "identity:update_user" => "rule:admin_required",
  "identity:delete_user" => "rule:admin_required",
  "identity:change_password" => "rule:admin_or_owner",

  "identity:get_group" => "rule:admin_required",
  "identity:list_groups" => "rule:admin_required",
  "identity:list_groups_for_user" => "rule:admin_or_owner",
  "identity:create_group" => "rule:admin_required",
  "identity:update_group" => "rule:admin_required",
  "identity:delete_group" => "rule:admin_required",
  "identity:list_users_in_group" => "rule:admin_required",
  "identity:remove_user_from_group" => "rule:admin_required",
  "identity:check_user_in_group" => "rule:admin_required",
  "identity:add_user_to_group" => "rule:admin_required",

  "identity:get_credential" => "rule:admin_required",
  "identity:list_credentials" => "rule:admin_required",
  "identity:create_credential" => "rule:admin_required",
  "identity:update_credential" => "rule:admin_required",
  "identity:delete_credential" => "rule:admin_required",

  "identity:ec2_get_credential" => "rule:admin_required or (rule:owner and user_id:%(target.credential.user_id)s)",
  "identity:ec2_list_credentials" => "rule:admin_or_owner",
  "identity:ec2_create_credential" => "rule:admin_or_owner",
  "identity:ec2_delete_credential" => "rule:admin_required or (rule:owner and user_id:%(target.credential.user_id)s)",

  "identity:get_role" => "rule:admin_required",
  "identity:list_roles" => "rule:admin_required",
  "identity:create_role" => "rule:admin_required",
  "identity:update_role" => "rule:admin_required",
  "identity:delete_role" => "rule:admin_required",

  "identity:check_grant" => "rule:admin_required",
  "identity:list_grants" => "rule:admin_required",
  "identity:create_grant" => "rule:admin_required",
  "identity:revoke_grant" => "rule:admin_required",

  "identity:list_role_assignments" => "rule:admin_required",

  "identity:get_policy" => "rule:admin_required",
  "identity:list_policies" => "rule:admin_required",
  "identity:create_policy" => "rule:admin_required",
  "identity:update_policy" => "rule:admin_required",
  "identity:delete_policy" => "rule:admin_required",

  "identity:check_token" => "rule:admin_required",
  "identity:validate_token" => "rule:service_or_admin",
  "identity:validate_token_head" => "rule:service_or_admin",
  "identity:revocation_list" => "rule:service_or_admin",
  "identity:revoke_token" => "rule:admin_or_token_subject",

  "identity:create_trust" => "user_id:%(trust.trustor_user_id)s",
  "identity:get_trust" => "rule:admin_or_owner",
  "identity:list_trusts" => "",
  "identity:list_roles_for_trust" => "",
  "identity:get_role_for_trust" => "",
  "identity:delete_trust" => "",

  "identity:create_consumer" => "rule:admin_required",
  "identity:get_consumer" => "rule:admin_required",
  "identity:list_consumers" => "rule:admin_required",
  "identity:delete_consumer" => "rule:admin_required",
  "identity:update_consumer" => "rule:admin_required",

  "identity:authorize_request_token" => "rule:admin_required",
  "identity:list_access_token_roles" => "rule:admin_required",
  "identity:get_access_token_role" => "rule:admin_required",
  "identity:list_access_tokens" => "rule:admin_required",
  "identity:get_access_token" => "rule:admin_required",
  "identity:delete_access_token" => "rule:admin_required",

  "identity:list_projects_for_endpoint" => "rule:admin_required",
  "identity:add_endpoint_to_project" => "rule:admin_required",
  "identity:check_endpoint_in_project" => "rule:admin_required",
  "identity:list_endpoints_for_project" => "rule:admin_required",
  "identity:remove_endpoint_from_project" => "rule:admin_required",

  "identity:create_endpoint_group" => "rule:admin_required",
  "identity:list_endpoint_groups" => "rule:admin_required",
  "identity:get_endpoint_group" => "rule:admin_required",
  "identity:update_endpoint_group" => "rule:admin_required",
  "identity:delete_endpoint_group" => "rule:admin_required",
  "identity:list_projects_associated_with_endpoint_group" => "rule:admin_required",
  "identity:list_endpoints_associated_with_endpoint_group" => "rule:admin_required",
  "identity:get_endpoint_group_in_project" => "rule:admin_required",
  "identity:add_endpoint_group_to_project" => "rule:admin_required",
  "identity:remove_endpoint_group_from_project" => "rule:admin_required",

  "identity:create_identity_provider" => "rule:admin_required",
  "identity:list_identity_providers" => "rule:admin_required",
  "identity:get_identity_providers" => "rule:admin_required",
  "identity:update_identity_provider" => "rule:admin_required",
  "identity:delete_identity_provider" => "rule:admin_required",

  "identity:create_protocol" => "rule:admin_required",
  "identity:update_protocol" => "rule:admin_required",
  "identity:get_protocol" => "rule:admin_required",
  "identity:list_protocols" => "rule:admin_required",
  "identity:delete_protocol" => "rule:admin_required",

  "identity:create_mapping" => "rule:admin_required",
  "identity:get_mapping" => "rule:admin_required",
  "identity:list_mappings" => "rule:admin_required",
  "identity:delete_mapping" => "rule:admin_required",
  "identity:update_mapping" => "rule:admin_required",

  "identity:create_service_provider" => "rule:admin_required",
  "identity:list_service_providers" => "rule:admin_required",
  "identity:get_service_provider" => "rule:admin_required",
  "identity:update_service_provider" => "rule:admin_required",
  "identity:delete_service_provider" => "rule:admin_required",

  "identity:get_auth_catalog" => "",
  "identity:get_auth_projects" => "",
  "identity:get_auth_domains" => "",

  "identity:list_projects_for_groups" => "",
  "identity:list_domains_for_groups" => "",

  "identity:list_revoke_events" => "",

  "identity:create_policy_association_for_endpoint" => "rule:admin_required",
  "identity:check_policy_association_for_endpoint" => "rule:admin_required",
  "identity:delete_policy_association_for_endpoint" => "rule:admin_required",
  "identity:create_policy_association_for_service" => "rule:admin_required",
  "identity:check_policy_association_for_service" => "rule:admin_required",
  "identity:delete_policy_association_for_service" => "rule:admin_required",
  "identity:create_policy_association_for_region_and_service" => "rule:admin_required",
  "identity:check_policy_association_for_region_and_service" => "rule:admin_required",
  "identity:delete_policy_association_for_region_and_service" => "rule:admin_required",
  "identity:get_policy_for_endpoint" => "rule:admin_required",
  "identity:list_endpoints_for_policy" => "rule:admin_required",

  "identity:create_domain_config" => "rule:admin_required",
  "identity:get_domain_config" => "rule:admin_required",
  "identity:update_domain_config" => "rule:admin_required",
  "identity:delete_domain_config" => "rule:admin_required"
}

###########################################
#
#  Nova Settings
#
###########################################
#
# Over-allocation settings. Set according to your cluster
# SLAs. Default is to not allow over allocation of memory
# a slight over allocation of CPU (x2). 
default['bcpc']['nova']['ram_allocation_ratio'] = 1.0
default['bcpc']['nova']['reserved_host_memory_mb'] = 1024
default['bcpc']['nova']['cpu_allocation_ratio'] = 2.0
# "workers" parameters in nova are set to number of CPUs
# available by default. This provides an override.
default['bcpc']['nova']['workers'] = 5
# Patch toggle for https://github.com/bloomberg/chef-bcpc/pull/493
default['bcpc']['nova']['live_migration_patch'] = false
# Nova debug toggle
default['bcpc']['nova']['debug'] = false
# Nova ephemeral - used to include or exclude rbd settings in nova.conf
default['bcpc']['nova']['persistent'] = true

# Nova scheduler default filters
default['bcpc']['nova']['scheduler_default_filters'] = ['AggregateInstanceExtraSpecsFilter', 'AvailabilityZoneFilter', 'RamFilter', 'ComputeFilter', 'DifferentHostFilter', 'SameHostFilter']
default['bcpc']['nova']['quota'] = {
  "cores" => 4,
  "floating_ips" => 10,
  "gigabytes"=> 1000,
  "instances" => 10,
  "ram" => 51200
}

# load a custom vendor driver, 
# e.g. "nova.api.metadata.bcpc_metadata.BcpcMetadata", 
# comment out to use default
#default['bcpc']['vendordata_driver'] = "nova.api.metadata.bcpc_metadata.BcpcMetadata"

###########################################
#
#  Nova policy Settings
#
###########################################
default['bcpc']['nova']['policy'] = {
  "context_is_admin" => "role:admin",
  "admin_or_owner" => "is_admin:True or project_id:%(project_id)s",
  "default" => "rule:admin_or_owner",

  "cells_scheduler_filter:TargetCellFilter" => "is_admin:True",

  "compute:create" => "",
  "compute:create:attach_network" => "",
  "compute:create:attach_volume" => "",
  "compute:create:forced_host" => "is_admin:True",
  "compute:get_all" => "",
  "compute:get_all_tenants" => "",
  "compute:start" => "rule:admin_or_owner",
  "compute:stop" => "rule:admin_or_owner",
  "compute:unlock_override" => "rule:admin_api",

  "compute:shelve" => "",
  "compute:shelve_offload" => "",
  "compute:unshelve" => "",
  "compute:resize" => "",
  "compute:confirm_resize" => "",
  "compute:revert_resize" => "",
  "compute:rebuild" => "",
  "compute:reboot" => "",

  "compute:volume_snapshot_create" => "",
  "compute:volume_snapshot_delete" => "",

  "admin_api" => "is_admin:True",
  "compute_extension:accounts" => "rule:admin_api",
  "compute_extension:admin_actions" => "rule:admin_api",
  "compute_extension:admin_actions:pause" => "rule:admin_or_owner",
  "compute_extension:admin_actions:unpause" => "rule:admin_or_owner",
  "compute_extension:admin_actions:suspend" => "rule:admin_or_owner",
  "compute_extension:admin_actions:resume" => "rule:admin_or_owner",
  "compute_extension:admin_actions:lock" => "rule:admin_or_owner",
  "compute_extension:admin_actions:unlock" => "rule:admin_or_owner",
  "compute_extension:admin_actions:resetNetwork" => "rule:admin_api",
  "compute_extension:admin_actions:injectNetworkInfo" => "rule:admin_api",
  "compute_extension:admin_actions:createBackup" => "rule:admin_or_owner",
  "compute_extension:admin_actions:migrateLive" => "rule:admin_api",
  "compute_extension:admin_actions:resetState" => "rule:admin_api",
  "compute_extension:admin_actions:migrate" => "rule:admin_api",
  "compute_extension:aggregates" => "rule:admin_api",
  "compute_extension:agents" => "rule:admin_api",
  "compute_extension:attach_interfaces" => "",
  "compute_extension:baremetal_nodes" => "rule:admin_api",
  "compute_extension:cells" => "rule:admin_api",
  "compute_extension:cells:create" => "rule:admin_api",
  "compute_extension:cells:delete" => "rule:admin_api",
  "compute_extension:cells:update" => "rule:admin_api",
  "compute_extension:cells:sync_instances" => "rule:admin_api",
  "compute_extension:certificates" => "",
  "compute_extension:cloudpipe" => "rule:admin_api",
  "compute_extension:cloudpipe_update" => "rule:admin_api",
  "compute_extension:console_output" => "",
  "compute_extension:consoles" => "",
  "compute_extension:createserverext" => "",
  "compute_extension:deferred_delete" => "",
  "compute_extension:disk_config" => "",
  "compute_extension:evacuate" => "rule:admin_api",
  "compute_extension:extended_server_attributes" => "rule:admin_api",
  "compute_extension:extended_status" => "",
  "compute_extension:extended_availability_zone" => "",
  "compute_extension:extended_ips" => "",
  "compute_extension:extended_ips_mac" => "",
  "compute_extension:extended_vif_net" => "",
  "compute_extension:extended_volumes" => "",
  "compute_extension:fixed_ips" => "rule:admin_api",
  "compute_extension:flavor_access" => "",
  "compute_extension:flavor_access:addTenantAccess" => "rule:admin_api",
  "compute_extension:flavor_access:removeTenantAccess" => "rule:admin_api",
  "compute_extension:flavor_disabled" => "",
  "compute_extension:flavor_rxtx" => "",
  "compute_extension:flavor_swap" => "",
  "compute_extension:flavorextradata" => "",
  "compute_extension:flavorextraspecs:index" => "",
  "compute_extension:flavorextraspecs:show" => "",
  "compute_extension:flavorextraspecs:create" => "rule:admin_api",
  "compute_extension:flavorextraspecs:update" => "rule:admin_api",
  "compute_extension:flavorextraspecs:delete" => "rule:admin_api",
  "compute_extension:flavormanage" => "rule:admin_api",
  "compute_extension:floating_ip_dns" => "",
  "compute_extension:floating_ip_pools" => "",
  "compute_extension:floating_ips" => "",
  "compute_extension:floating_ips_bulk" => "rule:admin_api",
  "compute_extension:fping" => "",
  "compute_extension:fping:all_tenants" => "rule:admin_api",
  "compute_extension:hide_server_addresses" => "is_admin:False",
  "compute_extension:hosts" => "rule:admin_api",
  "compute_extension:hypervisors" => "rule:admin_api",
  "compute_extension:image_size" => "",
  "compute_extension:instance_actions" => "",
  "compute_extension:instance_actions:events" => "rule:admin_api",
  "compute_extension:instance_usage_audit_log" => "rule:admin_api",
  "compute_extension:keypairs" => "",
  "compute_extension:keypairs:index" => "",
  "compute_extension:keypairs:show" => "",
  "compute_extension:keypairs:create" => "",
  "compute_extension:keypairs:delete" => "",
  "compute_extension:multinic" => "",
  "compute_extension:networks" => "rule:admin_api",
  "compute_extension:networks:view" => "",
  "compute_extension:networks_associate" => "rule:admin_api",
  "compute_extension:quotas:show" => "",
  "compute_extension:quotas:update" => "rule:admin_api",
  "compute_extension:quotas:delete" => "rule:admin_api",
  "compute_extension:quota_classes" => "",
  "compute_extension:rescue" => "",
  "compute_extension:security_group_default_rules" => "rule:admin_api",
  "compute_extension:security_groups" => "",
  "compute_extension:server_diagnostics" => "rule:admin_api",
  "compute_extension:server_groups" => "",
  "compute_extension:server_password" => "",
  "compute_extension:server_usage" => "",
  "compute_extension:services" => "rule:admin_api",
  "compute_extension:shelve" => "",
  "compute_extension:shelveOffload" => "rule:admin_api",
  "compute_extension:simple_tenant_usage:show" => "rule:admin_or_owner",
  "compute_extension:simple_tenant_usage:list" => "rule:admin_api",
  "compute_extension:unshelve" => "",
  "compute_extension:users" => "rule:admin_api",
  "compute_extension:virtual_interfaces" => "",
  "compute_extension:virtual_storage_arrays" => "",
  "compute_extension:volumes" => "",
  "compute_extension:volume_attachments:index" => "",
  "compute_extension:volume_attachments:show" => "",
  "compute_extension:volume_attachments:create" => "",
  "compute_extension:volume_attachments:update" => "",
  "compute_extension:volume_attachments:delete" => "",
  "compute_extension:volumetypes" => "",
  "compute_extension:availability_zone:list" => "",
  "compute_extension:availability_zone:detail" => "rule:admin_api",
  "compute_extension:used_limits_for_admin" => "rule:admin_api",
  "compute_extension:migrations:index" => "rule:admin_api",
  "compute_extension:os-assisted-volume-snapshots:create" => "rule:admin_api",
  "compute_extension:os-assisted-volume-snapshots:delete" => "rule:admin_api",
  "compute_extension:console_auth_tokens" => "rule:admin_api",
  "compute_extension:os-server-external-events:create" => "rule:admin_api",

  "network:get_all" => "",
  "network:get" => "",
  "network:create" => "",
  "network:delete" => "",
  "network:associate" => "",
  "network:disassociate" => "",
  "network:get_vifs_by_instance" => "",
  "network:allocate_for_instance" => "",
  "network:deallocate_for_instance" => "",
  "network:validate_networks" => "",
  "network:get_instance_uuids_by_ip_filter" => "",
  "network:get_instance_id_by_floating_address" => "",
  "network:setup_networks_on_host" => "",
  "network:get_backdoor_port" => "",

  "network:get_floating_ip" => "",
  "network:get_floating_ip_pools" => "",
  "network:get_floating_ip_by_address" => "",
  "network:get_floating_ips_by_project" => "",
  "network:get_floating_ips_by_fixed_address" => "",
  "network:allocate_floating_ip" => "",
  "network:associate_floating_ip" => "",
  "network:disassociate_floating_ip" => "",
  "network:release_floating_ip" => "",
  "network:migrate_instance_start" => "",
  "network:migrate_instance_finish" => "",

  "network:get_fixed_ip" => "",
  "network:get_fixed_ip_by_address" => "",
  "network:add_fixed_ip_to_instance" => "",
  "network:remove_fixed_ip_from_instance" => "",
  "network:add_network_to_project" => "",
  "network:get_instance_nw_info" => "",

  "network:get_dns_domains" => "",
  "network:add_dns_entry" => "",
  "network:modify_dns_entry" => "",
  "network:delete_dns_entry" => "",
  "network:get_dns_entries_by_address" => "",
  "network:get_dns_entries_by_name" => "",
  "network:create_private_dns_domain" => "",
  "network:create_public_dns_domain" => "",
  "network:delete_dns_domain" => "",
  "network:attach_external_network" => "rule:admin_api",

  "os_compute_api:servers:start" => "rule:admin_or_owner",
  "os_compute_api:servers:stop" => "rule:admin_or_owner",
  "os_compute_api:os-access-ips:discoverable" => "",
  "os_compute_api:os-access-ips" => "",
  "os_compute_api:os-admin-actions" => "rule:admin_api",
  "os_compute_api:os-admin-actions:discoverable" => "",
  "os_compute_api:os-admin-actions:reset_network" => "rule:admin_api",
  "os_compute_api:os-admin-actions:inject_network_info" => "rule:admin_api",
  "os_compute_api:os-admin-actions:reset_state" => "rule:admin_api",
  "os_compute_api:os-admin-password" => "",
  "os_compute_api:os-admin-password:discoverable" => "",
  "os_compute_api:os-aggregates:discoverable" => "",
  "os_compute_api:os-aggregates:index" => "rule:admin_api",
  "os_compute_api:os-aggregates:create" => "rule:admin_api",
  "os_compute_api:os-aggregates:show" => "rule:admin_api",
  "os_compute_api:os-aggregates:update" => "rule:admin_api",
  "os_compute_api:os-aggregates:delete" => "rule:admin_api",
  "os_compute_api:os-aggregates:add_host" => "rule:admin_api",
  "os_compute_api:os-aggregates:remove_host" => "rule:admin_api",
  "os_compute_api:os-aggregates:set_metadata" => "rule:admin_api",
  "os_compute_api:os-agents" => "rule:admin_api",
  "os_compute_api:os-agents:discoverable" => "",
  "os_compute_api:os-attach-interfaces" => "",
  "os_compute_api:os-attach-interfaces:discoverable" => "",
  "os_compute_api:os-baremetal-nodes" => "rule:admin_api",
  "os_compute_api:os-baremetal-nodes:discoverable" => "",
  "os_compute_api:os-block-device-mapping-v1:discoverable" => "",
  "os_compute_api:os-cells" => "rule:admin_api",
  "os_compute_api:os-cells:create" => "rule:admin_api",
  "os_compute_api:os-cells:delete" => "rule:admin_api",
  "os_compute_api:os-cells:update" => "rule:admin_api",
  "os_compute_api:os-cells:sync_instances" => "rule:admin_api",
  "os_compute_api:os-cells:discoverable" => "",
  "os_compute_api:os-certificates:create" => "",
  "os_compute_api:os-certificates:show" => "",
  "os_compute_api:os-certificates:discoverable" => "",
  "os_compute_api:os-cloudpipe" => "rule:admin_api",
  "os_compute_api:os-cloudpipe:discoverable" => "",
  "os_compute_api:os-consoles:discoverable" => "",
  "os_compute_api:os-consoles:create" => "",
  "os_compute_api:os-consoles:delete" => "",
  "os_compute_api:os-consoles:index" => "",
  "os_compute_api:os-consoles:show" => "",
  "os_compute_api:os-console-output:discoverable" => "",
  "os_compute_api:os-console-output" => "",
  "os_compute_api:os-remote-consoles" => "",
  "os_compute_api:os-remote-consoles:discoverable" => "",
  "os_compute_api:os-create-backup:discoverable" => "",
  "os_compute_api:os-create-backup" => "rule:admin_or_owner",
  "os_compute_api:os-deferred-delete" => "",
  "os_compute_api:os-deferred-delete:discoverable" => "",
  "os_compute_api:os-disk-config" => "",
  "os_compute_api:os-disk-config:discoverable" => "",
  "os_compute_api:os-evacuate" => "rule:admin_api",
  "os_compute_api:os-evacuate:discoverable" => "",
  "os_compute_api:os-extended-server-attributes" => "rule:admin_api",
  "os_compute_api:os-extended-server-attributes:discoverable" => "",
  "os_compute_api:os-extended-status" => "",
  "os_compute_api:os-extended-status:discoverable" => "",
  "os_compute_api:os-extended-availability-zone" => "",
  "os_compute_api:os-extended-availability-zone:discoverable" => "",
  "os_compute_api:extension_info:discoverable" => "",
  "os_compute_api:os-extended-volumes" => "",
  "os_compute_api:os-extended-volumes:discoverable" => "",
  "os_compute_api:os-fixed-ips" => "rule:admin_api",
  "os_compute_api:os-fixed-ips:discoverable" => "",
  "os_compute_api:os-flavor-access" => "",
  "os_compute_api:os-flavor-access:discoverable" => "",
  "os_compute_api:os-flavor-access:remove_tenant_access" => "rule:admin_api",
  "os_compute_api:os-flavor-access:add_tenant_access" => "rule:admin_api",
  "os_compute_api:os-flavor-rxtx" => "",
  "os_compute_api:os-flavor-rxtx:discoverable" => "",
  "os_compute_api:flavors:discoverable" => "",
  "os_compute_api:os-flavor-extra-specs:discoverable" => "",
  "os_compute_api:os-flavor-extra-specs:index" => "",
  "os_compute_api:os-flavor-extra-specs:show" => "",
  "os_compute_api:os-flavor-extra-specs:create" => "rule:admin_api",
  "os_compute_api:os-flavor-extra-specs:update" => "rule:admin_api",
  "os_compute_api:os-flavor-extra-specs:delete" => "rule:admin_api",
  "os_compute_api:os-flavor-manage:discoverable" => "",
  "os_compute_api:os-flavor-manage" => "rule:admin_api",
  "os_compute_api:os-floating-ip-dns" => "",
  "os_compute_api:os-floating-ip-dns:discoverable" => "",
  "os_compute_api:os-floating-ip-pools" => "",
  "os_compute_api:os-floating-ip-pools:discoverable" => "",
  "os_compute_api:os-floating-ips" => "",
  "os_compute_api:os-floating-ips:discoverable" => "",
  "os_compute_api:os-floating-ips-bulk" => "rule:admin_api",
  "os_compute_api:os-floating-ips-bulk:discoverable" => "",
  "os_compute_api:os-fping" => "",
  "os_compute_api:os-fping:discoverable" => "",
  "os_compute_api:os-fping:all_tenants" => "rule:admin_api",
  "os_compute_api:os-hide-server-addresses" => "is_admin:False",
  "os_compute_api:os-hide-server-addresses:discoverable" => "",
  "os_compute_api:os-hosts" => "rule:admin_api",
  "os_compute_api:os-hosts:discoverable" => "",
  "os_compute_api:os-hypervisors" => "rule:admin_api",
  "os_compute_api:os-hypervisors:discoverable" => "",
  "os_compute_api:images:discoverable" => "",
  "os_compute_api:image-size" => "",
  "os_compute_api:image-size:discoverable" => "",
  "os_compute_api:os-instance-actions" => "",
  "os_compute_api:os-instance-actions:discoverable" => "",
  "os_compute_api:os-instance-actions:events" => "rule:admin_api",
  "os_compute_api:os-instance-usage-audit-log" => "rule:admin_api",
  "os_compute_api:os-instance-usage-audit-log:discoverable" => "",
  "os_compute_api:ips:discoverable" => "",
  "os_compute_api:ips:index" => "rule:admin_or_owner",
  "os_compute_api:ips:show" => "rule:admin_or_owner",
  "os_compute_api:os-keypairs:discoverable" => "",
  "os_compute_api:os-keypairs" => "",
  "os_compute_api:os-keypairs:index" => "",
  "os_compute_api:os-keypairs:show" => "",
  "os_compute_api:os-keypairs:create" => "",
  "os_compute_api:os-keypairs:delete" => "",
  "os_compute_api:limits:discoverable" => "",
  "os_compute_api:os-lock-server:discoverable" => "",
  "os_compute_api:os-lock-server:lock" => "rule:admin_or_owner",
  "os_compute_api:os-lock-server:unlock" => "rule:admin_or_owner",
  "os_compute_api:os-migrate-server:discoverable" => "",
  "os_compute_api:os-migrate-server:migrate" => "rule:admin_api",
  "os_compute_api:os-migrate-server:migrate_live" => "rule:admin_api",
  "os_compute_api:os-multinic" => "",
  "os_compute_api:os-multinic:discoverable" => "",
  "os_compute_api:os-networks" => "rule:admin_api",
  "os_compute_api:os-networks:view" => "",
  "os_compute_api:os-networks:discoverable" => "",
  "os_compute_api:os-networks-associate" => "rule:admin_api",
  "os_compute_api:os-networks-associate:discoverable" => "",
  "os_compute_api:os-pause-server:discoverable" => "",
  "os_compute_api:os-pause-server:pause" => "rule:admin_or_owner",
  "os_compute_api:os-pause-server:unpause" => "rule:admin_or_owner",
  "os_compute_api:os-pci:pci_servers" => "",
  "os_compute_api:os-pci:discoverable" => "",
  "os_compute_api:os-pci:index" => "rule:admin_api",
  "os_compute_api:os-pci:detail" => "rule:admin_api",
  "os_compute_api:os-pci:show" => "rule:admin_api",
  "os_compute_api:os-personality:discoverable" => "",
  "os_compute_api:os-preserve-ephemeral-rebuild:discoverable" => "",
  "os_compute_api:os-quota-sets:discoverable" => "",
  "os_compute_api:os-quota-sets:show" => "",
  "os_compute_api:os-quota-sets:update" => "rule:admin_api",
  "os_compute_api:os-quota-sets:delete" => "rule:admin_api",
  "os_compute_api:os-quota-sets:detail" => "rule:admin_api",
  "os_compute_api:os-quota-class-sets" => "",
  "os_compute_api:os-quota-class-sets:discoverable" => "",
  "os_compute_api:os-rescue" => "",
  "os_compute_api:os-rescue:discoverable" => "",
  "os_compute_api:os-scheduler-hints:discoverable" => "",
  "os_compute_api:os-security-group-default-rules:discoverable" => "",
  "os_compute_api:os-security-group-default-rules" => "rule:admin_api",
  "os_compute_api:os-security-groups" => "",
  "os_compute_api:os-security-groups:discoverable" => "",
  "os_compute_api:os-server-diagnostics" => "rule:admin_api",
  "os_compute_api:os-server-diagnostics:discoverable" => "",
  "os_compute_api:os-server-password" => "",
  "os_compute_api:os-server-password:discoverable" => "",
  "os_compute_api:os-server-usage" => "",
  "os_compute_api:os-server-usage:discoverable" => "",
  "os_compute_api:os-server-groups" => "",
  "os_compute_api:os-server-groups:discoverable" => "",
  "os_compute_api:os-services" => "rule:admin_api",
  "os_compute_api:os-services:discoverable" => "",
  "os_compute_api:server-metadata:discoverable" => "",
  "os_compute_api:server-metadata:index" => "rule:admin_or_owner",
  "os_compute_api:server-metadata:show" => "rule:admin_or_owner",
  "os_compute_api:server-metadata:delete" => "rule:admin_or_owner",
  "os_compute_api:server-metadata:create" => "rule:admin_or_owner",
  "os_compute_api:server-metadata:update" => "rule:admin_or_owner",
  "os_compute_api:server-metadata:update_all" => "rule:admin_or_owner",
  "os_compute_api:servers:discoverable" => "",
  "os_compute_api:os-shelve:shelve" => "",
  "os_compute_api:os-shelve:shelve:discoverable" => "",
  "os_compute_api:os-shelve:shelve_offload" => "rule:admin_api",
  "os_compute_api:os-simple-tenant-usage:discoverable" => "",
  "os_compute_api:os-simple-tenant-usage:show" => "rule:admin_or_owner",
  "os_compute_api:os-simple-tenant-usage:list" => "rule:admin_api",
  "os_compute_api:os-suspend-server:discoverable" => "",
  "os_compute_api:os-suspend-server:suspend" => "rule:admin_or_owner",
  "os_compute_api:os-suspend-server:resume" => "rule:admin_or_owner",
  "os_compute_api:os-tenant-networks" => "rule:admin_or_owner",
  "os_compute_api:os-tenant-networks:discoverable" => "",
  "os_compute_api:os-shelve:unshelve" => "",
  "os_compute_api:os-user-data:discoverable" => "",
  "os_compute_api:os-virtual-interfaces" => "",
  "os_compute_api:os-virtual-interfaces:discoverable" => "",
  "os_compute_api:os-volumes" => "",
  "os_compute_api:os-volumes:discoverable" => "",
  "os_compute_api:os-volumes-attachments:index" => "",
  "os_compute_api:os-volumes-attachments:show" => "",
  "os_compute_api:os-volumes-attachments:create" => "",
  "os_compute_api:os-volumes-attachments:update" => "",
  "os_compute_api:os-volumes-attachments:delete" => "",
  "os_compute_api:os-volumes-attachments:discoverable" => "",
  "os_compute_api:os-availability-zone:list" => "",
  "os_compute_api:os-availability-zone:discoverable" => "",
  "os_compute_api:os-availability-zone:detail" => "rule:admin_api",
  "os_compute_api:os-used-limits" => "rule:admin_api",
  "os_compute_api:os-used-limits:discoverable" => "",
  "os_compute_api:os-migrations:index" => "rule:admin_api",
  "os_compute_api:os-migrations:discoverable" => "",
  "os_compute_api:os-assisted-volume-snapshots:create" => "rule:admin_api",
  "os_compute_api:os-assisted-volume-snapshots:delete" => "rule:admin_api",
  "os_compute_api:os-assisted-volume-snapshots:discoverable" => "",
  "os_compute_api:os-console-auth-tokens" => "rule:admin_api",
  "os_compute_api:os-server-external-events:create" => "rule:admin_api"
}

###########################################
#
#  Cinder Settings
#
###########################################
default['bcpc']['cinder']['quota'] = {
  "volumes" => 10,
  "quota_snapshots" => 10,
  "consistencygroups" => 10,
  "gigabytes" => 1000
}

###########################################
#
#  Cinder policy Settings
#
###########################################
default['bcpc']['cinder']['policy'] = {
  "context_is_admin" => "role:admin",
  "admin_or_owner" => "is_admin:True or project_id:%(project_id)s",
  "default" => "rule:admin_or_owner",

  "admin_api" => "is_admin:True",

  "volume:create" => "",
  "volume:delete" => "",
  "volume:get" => "",
  "volume:get_all" => "",
  "volume:get_volume_metadata" => "",
  "volume:get_volume_admin_metadata" => "rule:admin_api",
  "volume:delete_volume_admin_metadata" => "rule:admin_api",
  "volume:update_volume_admin_metadata" => "rule:admin_api",
  "volume:get_snapshot" => "",
  "volume:get_all_snapshots" => "",
  "volume:extend" => "",
  "volume:update_readonly_flag" => "",
  "volume:retype" => "",

  "volume_extension:types_manage" => "rule:admin_api",
  "volume_extension:types_extra_specs" => "rule:admin_api",
  "volume_extension:volume_type_access" => "",
  "volume_extension:volume_type_access:addProjectAccess" => "rule:admin_api",
  "volume_extension:volume_type_access:removeProjectAccess" => "rule:admin_api",
  "volume_extension:volume_type_encryption" => "rule:admin_api",
  "volume_extension:volume_encryption_metadata" => "rule:admin_or_owner",
  "volume_extension:extended_snapshot_attributes" => "",
  "volume_extension:volume_image_metadata" => "",

  "volume_extension:quotas:show" => "",
  "volume_extension:quotas:update" => "rule:admin_api",
  "volume_extension:quota_classes" => "",

  "volume_extension:volume_admin_actions:reset_status" => "rule:admin_api",
  "volume_extension:snapshot_admin_actions:reset_status" => "rule:admin_api",
  "volume_extension:backup_admin_actions:reset_status" => "rule:admin_api",
  "volume_extension:volume_admin_actions:force_delete" => "rule:admin_api",
  "volume_extension:volume_admin_actions:force_detach" => "rule:admin_api",
  "volume_extension:snapshot_admin_actions:force_delete" => "rule:admin_api",
  "volume_extension:volume_admin_actions:migrate_volume" => "rule:admin_api",
  "volume_extension:volume_admin_actions:migrate_volume_completion" => "rule:admin_api",

  "volume_extension:volume_host_attribute" => "rule:admin_api",
  "volume_extension:volume_tenant_attribute" => "rule:admin_or_owner",
  "volume_extension:volume_mig_status_attribute" => "rule:admin_api",
  "volume_extension:hosts" => "rule:admin_api",
  "volume_extension:services" => "rule:admin_api",

  "volume_extension:volume_manage" => "rule:admin_api",
  "volume_extension:volume_unmanage" => "rule:admin_api",

  "volume:services" => "rule:admin_api",

  "volume:create_transfer" => "",
  "volume:accept_transfer" => "",
  "volume:delete_transfer" => "",
  "volume:get_all_transfers" => "",

  "volume_extension:replication:promote" => "rule:admin_api",
  "volume_extension:replication:reenable" => "rule:admin_api",

  "backup:create" => "",
  "backup:delete" => "",
  "backup:get" => "",
  "backup:get_all" => "",
  "backup:restore" => "",
  "backup:backup-import" => "rule:admin_api",
  "backup:backup-export" => "rule:admin_api",

  "snapshot_extension:snapshot_actions:update_snapshot_status" => "",

  "consistencygroup:create" => "group:nobody",
  "consistencygroup:delete" => "group:nobody",
  "consistencygroup:update" => "group:nobody",
  "consistencygroup:get" => "group:nobody",
  "consistencygroup:get_all" => "group:nobody",

  "consistencygroup:create_cgsnapshot" => "group:nobody",
  "consistencygroup:delete_cgsnapshot" => "group:nobody",
  "consistencygroup:get_cgsnapshot" => "group:nobody",
  "consistencygroup:get_all_cgsnapshots" => "group:nobody",

  "scheduler_extension:scheduler_stats:get_pools" => "rule:admin_api"
}

###########################################
#
#  Glance policy Settings
#
###########################################
default['bcpc']['glance']['policy'] = {
  "context_is_admin" => "role:admin",
  "default" => "",

  "add_image" => "",
  "delete_image" => "",
  "get_image" => "",
  "get_images" => "",
  "modify_image" => "",
  "publicize_image" => "role:admin",
  "copy_from" => "",

  "download_image" => "",
  "upload_image" => "",

  "delete_image_location" => "",
  "get_image_location" => "",
  "set_image_location" => "",

  "add_member" => "",
  "delete_member" => "",
  "get_member" => "",
  "get_members" => "",
  "modify_member" => "",

  "manage_image_cache" => "role:admin",

  "get_task" => "",
  "get_tasks" => "",
  "add_task" => "",
  "modify_task" => "",

  "deactivate" => "",
  "reactivate" => "",

  "get_metadef_namespace" => "",
  "get_metadef_namespaces" => "",
  "modify_metadef_namespace" => "",
  "add_metadef_namespace" => "",

  "get_metadef_object" => "",
  "get_metadef_objects" => "",
  "modify_metadef_object" => "",
  "add_metadef_object" => "",

  "list_metadef_resource_types" => "",
  "get_metadef_resource_type" => "",
  "add_metadef_resource_type_association" => "",

  "get_metadef_property" => "",
  "get_metadef_properties" => "",
  "modify_metadef_property" => "",
  "add_metadef_property" => "",

  "get_metadef_tag" => "",
  "get_metadef_tags" => "",
  "modify_metadef_tag" => "",
  "add_metadef_tag" => "",
  "add_metadef_tags" => ""
}

###########################################
#
#  Heat policy Settings
#
###########################################
default['bcpc']['heat']['policy'] = {
  "deny_stack_user" => "not role:heat_stack_user",
  "deny_everybody" => "!",

  "cloudformation:ListStacks" => "rule:deny_stack_user",
  "cloudformation:CreateStack" => "rule:deny_stack_user",
  "cloudformation:DescribeStacks" => "rule:deny_stack_user",
  "cloudformation:DeleteStack" => "rule:deny_stack_user",
  "cloudformation:UpdateStack" => "rule:deny_stack_user",
  "cloudformation:CancelUpdateStack" => "rule:deny_stack_user",
  "cloudformation:DescribeStackEvents" => "rule:deny_stack_user",
  "cloudformation:ValidateTemplate" => "rule:deny_stack_user",
  "cloudformation:GetTemplate" => "rule:deny_stack_user",
  "cloudformation:EstimateTemplateCost" => "rule:deny_stack_user",
  "cloudformation:DescribeStackResource" => "",
  "cloudformation:DescribeStackResources" => "rule:deny_stack_user",
  "cloudformation:ListStackResources" => "rule:deny_stack_user",

  "cloudwatch:DeleteAlarms" => "rule:deny_stack_user",
  "cloudwatch:DescribeAlarmHistory" => "rule:deny_stack_user",
  "cloudwatch:DescribeAlarms" => "rule:deny_stack_user",
  "cloudwatch:DescribeAlarmsForMetric" => "rule:deny_stack_user",
  "cloudwatch:DisableAlarmActions" => "rule:deny_stack_user",
  "cloudwatch:EnableAlarmActions" => "rule:deny_stack_user",
  "cloudwatch:GetMetricStatistics" => "rule:deny_stack_user",
  "cloudwatch:ListMetrics" => "rule:deny_stack_user",
  "cloudwatch:PutMetricAlarm" => "rule:deny_stack_user",
  "cloudwatch:PutMetricData" => "",
  "cloudwatch:SetAlarmState" => "rule:deny_stack_user",

  "actions:action" => "rule:deny_stack_user",
  "build_info:build_info" => "rule:deny_stack_user",
  "events:index" => "rule:deny_stack_user",
  "events:show" => "rule:deny_stack_user",
  "resource:index" => "rule:deny_stack_user",
  "resource:metadata" => "",
  "resource:signal" => "",
  "resource:show" => "rule:deny_stack_user",
  "stacks:abandon" => "rule:deny_stack_user",
  "stacks:create" => "rule:deny_stack_user",
  "stacks:delete" => "rule:deny_stack_user",
  "stacks:detail" => "rule:deny_stack_user",
  "stacks:generate_template" => "rule:deny_stack_user",
  "stacks:global_index" => "rule:deny_everybody",
  "stacks:index" => "rule:deny_stack_user",
  "stacks:list_resource_types" => "rule:deny_stack_user",
  "stacks:lookup" => "",
  "stacks:preview" => "rule:deny_stack_user",
  "stacks:resource_schema" => "rule:deny_stack_user",
  "stacks:show" => "rule:deny_stack_user",
  "stacks:template" => "rule:deny_stack_user",
  "stacks:update" => "rule:deny_stack_user",
  "stacks:update_patch" => "rule:deny_stack_user",
  "stacks:validate_template" => "rule:deny_stack_user",
  "stacks:snapshot" => "rule:deny_stack_user",
  "stacks:show_snapshot" => "rule:deny_stack_user",
  "stacks:delete_snapshot" => "rule:deny_stack_user",
  "stacks:list_snapshots" => "rule:deny_stack_user",
  "stacks:restore_snapshot" => "rule:deny_stack_user",

  "software_configs:create" => "rule:deny_stack_user",
  "software_configs:show" => "rule:deny_stack_user",
  "software_configs:delete" => "rule:deny_stack_user",
  "software_deployments:index" => "rule:deny_stack_user",
  "software_deployments:create" => "rule:deny_stack_user",
  "software_deployments:show" => "rule:deny_stack_user",
  "software_deployments:update" => "rule:deny_stack_user",
  "software_deployments:delete" => "rule:deny_stack_user",
  "software_deployments:metadata" => "",

  "service:index" => "rule:context_is_admin"
}

###########################################
#
# Routemon settings
#
###########################################
#

# numfixes is how many times to try and fix default routes in the mgmt
# and storage networks when they disappear. If numfixes starts off at
# 0, or after 'numfixes' attempts have been made, then routemon
# subsequently only monitors and reports
#
default['bcpc']['routemon']['numfixes'] = 0

###########################################
#
# MySQL settings
#
###########################################
#
# If set to 0, max_connections for MySQL on heads will default to an
# auto-calculated value.
default['bcpc']['mysql-head']['max_connections'] = 0

###########################################
#
# CPU governor settings
#
###########################################
#
# Available options: conservative, ondemand, userspace, powersave, performance
# Review documentation at https://www.kernel.org/doc/Documentation/cpu-freq/governors.txt
default['bcpc']['cpupower']['governor'] = "ondemand"
default['bcpc']['cpupower']['ondemand_ignore_nice_load'] = nil
default['bcpc']['cpupower']['ondemand_io_is_busy'] = nil
default['bcpc']['cpupower']['ondemand_powersave_bias'] = nil
default['bcpc']['cpupower']['ondemand_sampling_down_factor'] = nil
default['bcpc']['cpupower']['ondemand_sampling_rate'] = nil
default['bcpc']['cpupower']['ondemand_up_threshold'] = nil

###########################################
#
# Graphite settings
#
###########################################
#
# Graphite Server FQDN
default['bcpc']['graphite']['fqdn'] = "graphite.#{node['bcpc']['domain_name']}"
#
# Default retention rates
# http://graphite.readthedocs.org/en/latest/config-carbon.html#storage-schemas-conf
default['bcpc']['graphite']['retention'] = '60s:1d'
#
###########################################
#
# Diamond settings
#
###########################################
#
# List of queue names separated by whitespace to report on. If nil, report all.
default['bcpc']['diamond']['collectors']['rabbitmq']['queues'] = nil
# Regular expression or list of queues to not report on.
# If not nil, this overrides "queues".
default['bcpc']['diamond']['collectors']['rabbitmq']['queues_ignored'] = '.*'
###########################################
#
# defaults for the bcpc.bootstrap settings
#
###########################################
#
# A value of nil means to let the Ubuntu installer work it out - it
# will try to find the nearest one. However the selected mirror is
# often slow.
default['bcpc']['bootstrap']['mirror'] = nil
#
# if you do specify a mirror, you can adjust the file path that comes
# after the hostname in the URL here
default['bcpc']['bootstrap']['mirror_path'] = "/ubuntu"
#
# Default retention rates
# http://graphite.readthedocs.org/en/latest/config-carbon.html#storage-schemas-conf
default['bcpc']['graphite']['retention'] = '60s:1d'

#
###########################################
#
# defaults for the bcpc.bootstrap settings
#
###########################################
#
# A value of nil means to let the Ubuntu installer work it out - it
# will try to find the nearest one. However the selected mirror is
# often slow.
default['bcpc']['bootstrap']['mirror'] = nil
#
# if you do specify a mirror, you can adjust the file path that comes
# after the hostname in the URL here
default['bcpc']['bootstrap']['mirror_path'] = "/ubuntu"
#
# worked example for the columbia mirror mentioned above which has a
# non-standard path
#default['bcpc']['bootstrap']['mirror']      = "mirror.cc.columbia.edu"
#default['bcpc']['bootstrap']['mirror_path'] = "/pub/linux/ubuntu/archive"

###########################################
#
# Rally settings
#
###########################################
#
# Package versions
# None needed at this time
default['bcpc']['rally']['user'] = 'ubuntu'

###########################################
#
# Openstack Flavors
#
###########################################

default['bcpc']['flavors']['deleted'] = []
default['bcpc']['flavors']['enabled'] = {}

###########################################
#
# Zabbix settings
#
###########################################
#
default['bcpc']['zabbix']['discovery']['delay'] = 600
default['bcpc']['zabbix']['discovery']['ip_ranges'] = [node['bcpc']['management']['cidr']]
default['bcpc']['zabbix']['fqdn'] = "zabbix.#{node['bcpc']['domain_name']}"
###########################################
#
# Kibana settings
#
###########################################
#
# Kibana Server FQDN
default['bcpc']['kibana']['fqdn'] = "kibana.#{node['bcpc']['domain_name']}"
