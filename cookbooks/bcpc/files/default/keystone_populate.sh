#!/usr/bin/env bash

# This script will create the needed services and endpoints that need to be entered into MySQL instead of just
# the default catalog template we're currently using. By setting the OS_SERVICE_xxxx environment variables we
# simply call 'keystone service-create' and 'keystone endpoint-create' which will add the respective values to
# the 'service' and 'endpoint' tables in the keystone database.
#
# By having these values in the database, we can then call the 'keystone service-* and keystone endpoint-*'
# functions which Rally and Tempest need. It causes no issues with continuing to use the template catalog.

# Place and run on specific head node since that is where each keystone is located.
# sudo chmod +x keystone_populate.sh
# Pass in the following parameters: (these are positional parameters so make sure they are all there and in order)
# $1 - Token used for installing Keystone. This can be found in the default.template.catalog under admin_token
# $2 - The head node IP (not the VIP IP) that the script is running on
# $3 - Region (i.e. CNJ1, etc)
# $4 - Keystone VIP IP (usually xxx.xxx.xxx.5 in our configuration)
# $5 - Ceph S3 Host IP (usually xxx.xxx.144.5 in our configuration)
# Example: ./keystone_populate.sh <token - whatever it is> <IP of head node> <region> <VIP IP> <Ceph S3 host IP>

if [ "$#" -ne 5 ]; then
    echo "Must pass in 5 parameters in order: <token> <IP of local machine> <region> <VIP IP> <Ceph S3 Host IP>"
    exit 1
fi

TOKEN=$1
IP=$2
KEYSTONE_REGION=$3
KEYSTONE_HOST=$4
CEPH_S3_HOST=$5

export OS_SERVICE_TOKEN=${TOKEN}

if [ ${IP} = ${KEYSTONE_HOST} ]; then
  export OS_SERVICE_ENDPOINT="https://${IP}:35357/v2.0"
else
  export OS_SERVICE_ENDPOINT="http://${IP}:35357/v2.0"
fi

# Grab a numbered field from python prettytable output
# Fields are numbered starting with 1
# get_field field-number
# Get the individual value from a delimited line (not a complete output)
function get_field {
    # The following line was used for testing and is not valid for actual use.
    #IFS='|' read -ra COL <<< "$1"
    IFS='|' read -ra COL
    echo $(trim ${COL[$1]})
}


# Utility function for trimming the value passed
function trim {
    echo ${1//[[:blank:]]/}
}

# There are two steps below. The first, keystone service-create, creates the base database record for the given
# service and returns the uuid needed for the endpoint association. The second, keystone endpoint-create, uses then
# uuid returned from step one and creates the endpoints to match those that are found in
# default.template.catalog in /etc/keystone. If need be, you can delete the service from the database by calling
# keystone service-delete uuid (note: uuid actually the real id from from running keystone service-list - just
# look for the specific service you're wanting to delete to get the right uuid (id) value. To run any of those commands
# you need the service token and service endpoint (see the export lines above on what it needs and how it works).
# Don't forget to unset the OS_SERVICE... environment variables after use.

# Check first before attempting to create service
check=$(keystone service-list | grep 'compute')
if [[ -z ${check} ]]; then
    COMPUTE_SERVICE=$(keystone service-create --name 'Computer Service' --type compute --description 'OpenStack Compute Service' | grep " id " | get_field 2)
fi

check=$(keystone service-list | grep 'volume')
if [[ -z ${check} ]]; then
    VOLUME_SERVICE=$(keystone service-create --name 'Volume Service' --type volume --description 'OpenStack Volume Service' | grep " id " | get_field 2)
fi

check=$(keystone service-list | grep 'object-store')
if [[ -z ${check} ]]; then
    OBJECT_SERVICE=$(keystone service-create --name 'Object Store Service' --type object-store --description 'OpenStack Object Storage Service' | grep " id " | get_field 2)
fi

check=$(keystone service-list | grep 'image')
if [[ -z ${check} ]]; then
    IMAGE_SERVICE=$(keystone service-create --name 'Image Service' --type image --description 'OpenStack Image Service' | grep " id " | get_field 2)
fi

check=$(keystone service-list | grep 'identity')
if [[ -z ${check} ]]; then
    # Had to change --name to 'keystone' so rally would work! Hardcoded values in Rally!
    IDENTITY_SERVICE=$(keystone service-create --name 'keystone' --type identity --description 'OpenStack Identity' | grep " id " | get_field 2)
fi

check=$(keystone service-list | grep 'ec2')
if [[ -z ${check} ]]; then
    EC2_SERVICE=$(keystone service-create --name 'EC2 Service' --type ec2 --description 'OpenStack EC2 service' | grep " id " | get_field 2)
fi

check=$(keystone service-list | grep 'orchestration')
if [[ -z ${check} ]]; then
    ORCHESTRATION_SERVICE=$(keystone service-create --name 'Orchestration Service' --type orchestration --description 'OpenStack Orchestration service' | grep " id " | get_field 2)
fi

check=$(keystone service-list | grep 'cloudformation')
if [[ -z ${check} ]]; then
    CLOUD_FORMATION_SERVICE=$(keystone service-create --name 'Cloudformation Service' --type cloudformation --description 'OpenStack Cloudformation service' | grep " id " | get_field 2)
fi

# Create endpoints - Output in pretty table format will show unless you want to re-direct output.
if [[ -z ${COMPUTE_SERVICE} ]]; then
    echo 'Compute Service exists or not created.'
else
    keystone endpoint-create --region ${KEYSTONE_REGION} --service-id ${COMPUTE_SERVICE} --publicurl 'https://'${KEYSTONE_HOST}':8774/v1.1/$(tenant_id)s' --adminurl 'https://'${KEYSTONE_HOST}':8774/v1.1/$(tenant_id)s' --internalurl 'https://'${KEYSTONE_HOST}':8774/v1.1/$(tenant_id)s'
fi

if [[ -z ${VOLUME_SERVICE} ]]; then
    echo 'Volume Service exists or not created.'
else
    keystone endpoint-create --region ${KEYSTONE_REGION} --service-id ${VOLUME_SERVICE} --publicurl 'https://'${KEYSTONE_HOST}':8776/v1/$(tenant_id)s' --adminurl 'https://'${KEYSTONE_HOST}':8776/v1/$(tenant_id)s' --internalurl 'https://'${KEYSTONE_HOST}':8776/v1/$(tenant_id)s'
fi

if [[ -z ${OBJECT_SERVICE} ]]; then
    echo 'Object Service exists or not created.'
else
    keystone endpoint-create --region ${KEYSTONE_REGION} --service-id ${OBJECT_SERVICE} --publicurl 'http://'${CEPH_S3_HOST}'/swift/v1' --adminurl 'http://'${CEPH_S3_HOST}'/swift/v1' --internalurl 'http://'${CEPH_S3_HOST}'/swift/v1'
fi

if [[ -z ${IMAGE_SERVICE} ]]; then
    echo 'Image Service exists or not created.'
else
    keystone endpoint-create --region ${KEYSTONE_REGION} --service-id ${IMAGE_SERVICE} --publicurl 'https://'${KEYSTONE_HOST}':9292/v1' --adminurl 'https://'${KEYSTONE_HOST}':9292/v1' --internalurl 'https://'${KEYSTONE_HOST}':9292/v1'
fi

if [[ -z ${IDENTITY_SERVICE} ]]; then
    echo 'Identity Service exists or not created.'
else
    keystone endpoint-create --region ${KEYSTONE_REGION} --service-id ${IDENTITY_SERVICE} --publicurl 'https://'${KEYSTONE_HOST}':5000/v2.0' --adminurl 'https://'${KEYSTONE_HOST}':35357/v2.0' --internalurl 'https://'${KEYSTONE_HOST}':5000/v2.0'
fi

if [[ -z ${EC2_SERVICE} ]]; then
    echo 'EC2 Service exists or not created.'
else
    keystone endpoint-create --region ${KEYSTONE_REGION} --service-id ${EC2_SERVICE} --publicurl 'https://'${KEYSTONE_HOST}':8773/services/Cloud' --adminurl 'https://'${KEYSTONE_HOST}':8773/services/Admin' --internalurl 'https://'${KEYSTONE_HOST}':8773/services/Cloud'
fi

if [[ -z ${ORCHESTRATION_SERVICE} ]]; then
    echo 'Orchestration Service exists or not created.'
else
    keystone endpoint-create --region ${KEYSTONE_REGION} --service-id ${ORCHESTRATION_SERVICE} --publicurl 'https://'${KEYSTONE_HOST}':8004/v1/$(tenant_id)s' --adminurl 'https://'${KEYSTONE_HOST}':8004/v1/$(tenant_id)s' --internalurl 'https://'${KEYSTONE_HOST}':8004/v1/$(tenant_id)s'
fi

if [[ -z ${CLOUD_FORMATION_SERVICE} ]]; then
    echo 'Cloudformation Service exists or not created.'
else
    keystone endpoint-create --region ${KEYSTONE_REGION} --service-id ${CLOUD_FORMATION_SERVICE} --publicurl 'https://'${KEYSTONE_HOST}':8000/v1' --adminurl 'https://'${KEYSTONE_HOST}':8000/v1' --internalurl 'https://'${KEYSTONE_HOST}':8000/v1'
fi

unset OS_SERVICE_TOKEN
unset OS_SERVICE_ENDPOINT
