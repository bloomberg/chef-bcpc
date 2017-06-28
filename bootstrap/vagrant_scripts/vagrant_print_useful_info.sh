#!/bin/bash
# Exit immediately if anything goes wrong, instead of making things worse.
set -e

. "$REPO_ROOT"/bootstrap/shared/shared_functions

REQUIRED_VARS=( BOOTSTRAP_CHEF_ENV REPO_ROOT )
check_for_envvars "${REQUIRED_VARS[@]}"

cd "$REPO_ROOT"/bootstrap/vagrant_scripts

KNIFE=/opt/opscode/embedded/bin/knife
# Dump the data bag contents to a variable.
DATA_BAG=$(vagrant ssh vm-bootstrap -c "$KNIFE data bag show configs $BOOTSTRAP_CHEF_ENV -F yaml")
# Get the management VIP.
MANAGEMENT_VIP=$(vagrant ssh vm-bootstrap -c "$KNIFE environment show $BOOTSTRAP_CHEF_ENV -a override_attributes.bcpc.management.vip | tail -n +2 | awk '{ print \$2 }'")

# this is highly naive for obvious reasons (will break on multi-line keys, spaces)
# but is sufficient for the items to be extracted here
extract_value() {
  echo "$DATA_BAG" | grep "$1:" | awk '{ print $2 }' | tr -d '\r\n'
}

# Parse certain data bag variables into environment variables for pretty printing.
ROOT_PASSWORD=$(extract_value 'cobbler-root-password')
MYSQL_ROOT_PASSWORD=$(extract_value 'mysql-root-password')
RABBITMQ_USER=$(extract_value 'rabbitmq-user')
RABBITMQ_PASSWORD=$(extract_value 'rabbitmq-password')
HAPROXY_USER=$(extract_value 'haproxy-stats-user')
HAPROXY_PASSWORD=$(extract_value 'haproxy-stats-password')
KEYSTONE_ADMIN_USER=$(extract_value 'keystone-admin-user')
KEYSTONE_ADMIN_PASSWORD=$(extract_value 'keystone-admin-password')

# Print everything out for the user.
echo "------------------------------------------------------------"
echo "Everything looks like it's been installed successfully!"
echo
echo "Access the BCPC landing page at https://$MANAGEMENT_VIP"
echo "Use these users and passwords to access the different resources:"
echo
echo "Horizon: $KEYSTONE_ADMIN_USER / $KEYSTONE_ADMIN_PASSWORD"
echo "HAProxy: $HAPROXY_USER / $HAPROXY_PASSWORD"
echo "RabbitMQ: $RABBITMQ_USER / $RABBITMQ_PASSWORD"
echo
echo "Here are a few additional passwords:"
echo "System root password: $ROOT_PASSWORD"
echo "MySQL root password: $MYSQL_ROOT_PASSWORD"
echo
echo "Thanks for using BCPC!"
