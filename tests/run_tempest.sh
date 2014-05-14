#!/bin/bash
set -e

. ../proxy_setup.sh

###
### Script to setup and run the Tempest (https://github.com/openstack/tempest)
### test suite against a BCPC cluster
###

printf "#### Setup Environment\n"
ENVIRONMENT="${1-Test-Laptop}"

FIRST_HEAD=$(grep -i 'head' ../cluster.txt | cut -f 3 -d' ' | tail -1)
VIP=$(cd ../; knife node show $(hostname) -a 'bcpc.management.vip' | tail -1 | sed 's/.* //')
BOOTSTRAP=$(cd ../; knife node show $(hostname) -a 'bcpc.management.ip' | tail -1 | sed 's/.* //')
# create a comma separated list of cluster node IP addresses (will have a trailing comma)
CLUSTER_NODES=$(sed -e 's/[^0-9. ]//g' -e 's/ /,/g' <<< $(cut -f 3 -d' ' ../cluster.txt))

ping -c 1 -W 5 $FIRST_HEAD >/dev/null 2>&1 && \
  printf "Pinging first headnode: ${FIRST_HEAD}\n" || \
  ( printf "Failed to ping first head node ${FIRST_HEAD}\n" > /dev/stderr; exit 1 )
ping -c 1 -W 5 $VIP >/dev/null 2>&1 && \
  printf "Pinging VIP: ${VIP}\n" || \
  ( printf "Failed to ping VIP ${VIP}\n" > /dev/stderr; exit 1 )
ping -c 1 -W 5 $BOOTSTRAP >/dev/null 2>&1 && \
  printf "Pinging bootstrap: ${BOOTSTRAP}\n" || \
  ( printf "Failed to ping bootstrap server ${BOOTSTRAP}\n" > /dev/stderr; exit 1 )

# grab the CIDR notation for the network (e.g. 10.0.100.0/24)
MANAGEMENT_CIDR=$(cd ../; knife node show $(hostname) -a 'bcpc.management.cidr' | tail -1 | sed 's/.* //')
FIXED_CIDR=$(cd ../; knife node show $(hostname) -a 'bcpc.fixed.cidr' | tail -1 | sed 's/.* //')
FLOATING_CIDR=$(cd ../; knife node show $(hostname) -a 'bcpc.floating.cidr' | tail -1 | sed 's/.* //')

# make a glob like 10.0.100.* for the network (for $no_proxy use)
MANAGEMENT_GLOB=$(sed -e 's#/.*##' -e 's/\(\.0\)*.[0-9]\{1,3\}$/.*/' <<< $MANAGEMENT_CIDR)
printf "Management glob: ${MANAGEMENT_GLOB}\n"
FIXED_GLOB=$(sed -e 's#/.*##' -e 's/\(\.0\)*.[0-9]\{1,3\}$/.*/' <<< $FIXED_CIDR)
printf "Fixed glob: ${FIXED_GLOB}\n"
FLOATING_GLOB=$(sed -e 's#/.*##' -e 's/\(\.0\)*.[0-9]\{1,3\}$/.*/' <<< $FLOATING_CIDR)
printf "Floating glob: ${FLOATING_GLOB}\n"

printf "#### Setup Directories\n"
TEST_DATA_DIR=test_data
mkdir -p $TEST_DATA_DIR
# generate test ssh-key
[[ -f ${TEST_DATA_DIR}/test_ssh_key ]] || ssh-keygen -t dsa -f ${TEST_DATA_DIR}/test_ssh_key -P ''

[[ -d ${TEST_DATA_DIR}/tempest ]] || git clone https://github.com/openstack/tempest.git -b stable/grizzly ${TEST_DATA_DIR}/tempest

# Setup nodessh/nodescp equivalents
cobbler_pass="$(cd ..; knife data bag show configs $ENVIRONMENT | grep 'cobbler-root-password:'|sed 's/.* //')"
SCP_HOST="sshpass -p $cobbler_pass scp -q -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o VerifyHostKeyDNS=no"
SSH_HOST="sshpass -p $cobbler_pass ssh -q -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o VerifyHostKeyDNS=no -l ubuntu"

# Allow ubuntu to read adminrc directly
echo $cobbler_pass | $SSH_HOST $FIRST_HEAD 'sudo -S chmod 755 /root/adminrc /root'

# Set up Ubuntu image
if ! $SSH_HOST $FIRST_HEAD 'source /root/adminrc;glance image-list | grep -q Ubuntu'; then
  $CURL http://cloud-images.ubuntu.com/precise/current/precise-server-cloudimg-amd64-disk1.img -o ${TEST_DATA_DIR}/ubuntu.img
  $SCP_HOST ${TEST_DATA_DIR}/ubuntu.img ubuntu@${FIRST_HEAD}:ubuntu.img
  $SSH_HOST $FIRST_HEAD 'source /root/adminrc; glance image-create --name Ubuntu --disk-format iso --container-format bare --file ubuntu.img --is-public True'
fi

# Copy ssh key to localhost
echo $cobbler_pass | $SSH_HOST $FIRST_HEAD 'sudo -S cat /root/.ssh/id_rsa' > ${TEST_DATA_DIR}/hypervisor_key
# sudo's in above $SSH_HOST commands do not print newlines so create one
printf "\n"

printf "#### Gather Tempest.CONF configurations\n"

# Cirros Image ID
cirros_image_id=$($SSH_HOST $FIRST_HEAD 'source /root/adminrc; glance image-list | grep Cirros | cut -f 2 -d"|" | grep -v "^+"')
# Ubuntu Image ID
ubuntu_image_id=$($SSH_HOST $FIRST_HEAD 'source /root/adminrc; glance image-list | grep Ubuntu | cut -f 2 -d"|" | grep -v "^+"')

# Tempest Flavor
flavor_ref=$($SSH_HOST $FIRST_HEAD 'source /root/adminrc; nova flavor-list|grep m1.tiny|cut -f 2 -d"|"')
# Tempest Flavor_ALT
flavor_ref_alt=$($SSH_HOST $FIRST_HEAD 'source /root/adminrc; nova flavor-list|grep m1.small|cut -f 2 -d"|"')
# Keystone Admin Pass
keystone_admin_pass=$(cd ../; knife data bag show configs $ENVIRONMENT |grep keystone-admin-password: | sed 's/.* //')
# Keystone Test User
keystone_test_user=$(cd ../; knife data bag show configs $ENVIRONMENT |grep keystone-test-user: | sed 's/.* //')
keystone_test_user_pass=$(cd ../; knife data bag show configs $ENVIRONMENT |grep keystone-test-password: | sed 's/.* //')

# images
export IMAGE_ID=$ubuntu_image_id
export IMAGE_ID_ALT=$cirros_image_id

printf "#### Modify tempest.conf for cluster\n"
# (setup the sections that are appropriate to the version of Tempest being run)
pushd ${TEST_DATA_DIR}/tempest
python << EOPYTHON
import ConfigParser
parser=ConfigParser.RawConfigParser()
with open("etc/tempest.conf.sample",mode="r") as input_f:
    parser.readfp(input_f)
configDir = {
 "cli": {"enabled": "true", "cli_dir": "/usr/bin"},
 "compute": {"allow_tenant_isolation": "true",
             "image_ref": "$IMAGE_ID",
             "image_ref_alt": "$IMAGE_ID_ALT",
             "flavor_ref": "$flavor_ref",
             "flavor_ref_alt": "$flavor_ref_alt",
             "image_ssh_user": "ubuntu",
             "image_alt_ssh_user": "cirros",
             "image_alt_ssh_password": "cubswin:)",
             "ssh_user": "ubuntu",
             "region": "$ENVIRONMENT",
             "path_to_private_key": "$(pwd)/${TEST_DATA_DIR}/test_ssh_key"},
 "compute-admin": {"tenant_name": "AdminTenant",
                   "password": "${keystone_admin_pass}"},
 "compute-feature-enabled": {"api_v3": "false",
                              "api_v3_extensions": "",
                              "change_password": "true", 
                              "create_image": "true"},
 "dashboard": {"dashboard_url": "https://${VIP}/horizon/",
               "login_url": "https://${VIP}/horizon/auth/login/"},
 "identity": {"uri": "https://${VIP}:5000/v2.0",
              "disable_ssl_certificate_validation": "true",
              "region": "$ENVIRONMENT",
              "username": "${keystone_test_user}",
              "tenant_name": "AdminTenant", 
              "password": "${keystone_test_user_pass}",
              "admin_username": "admin",
              "admin_tenant_name": "AdminTenant",
              "admin_password": "${keystone_admin_pass}"},
 "image": {"region": "$ENVIRONMENT",
           "http_image": "http://${BOOTSTRAP}:8080/cirros-0.3.0-x86_64-disk.img"},
 "input-scenario": {"image_regex": '[["^[Cc]irros.*$","^[Uu]buntu.*"]]',
                    "flavor_regex": "^m1.tiny",
                    "ssh_user_regex": '[["^.*[Cc]irros.*$", "ubuntu"]]'},
 "network": {"region": "$ENVIRONMENT",
             "tenant_network_cidr" : "1.127.0.0/16",
             "tenant_network_mask_bits": "25"},
 "object-storage": {"region": "$ENVIRONMENT"},
 "service_available": {"swift": "false",
                       "ceilometer": "false"},
 "stress": {"nova_logdir": "/var/log/nova",
            "target_ssh_user": "root",
            "target_private_key_path": "${pwd}/hypervisor_key",
            "target_logfiles": "nova.*\.log"},
 "volume": {"region": "$ENVIRONMENT",
            "backend1_name": "SSD",
            "backend2_name": "HDD",
            "storage_protocol": "RBD"},
 "whitebox": {"whitebox_enabled": "false"}
}
for sect in configDir:
    if sect not in parser.sections():
        continue
    for opt in configDir[sect]:
        parser.set(sect, opt, configDir[sect][opt])
with file("etc/tempest.conf", mode="w") as output_f:
    parser.write(output_f)
for sect in ["object-storage","boto"]:
    parser.remove_section(sect)
EOPYTHON
popd

printf "#### Install pre-requsite software\n"
sudo apt-get install -y testrepository python-nova
sudo -E easy_install virtualenv flake8
sudo -E pip install -r ${TEST_DATA_DIR}/tempest/tools/pip-requires

printf "#### Run Tempest\n"
export NO_PROXY="${CLUSTER_NODES}${BOOTSTRAP},${VIP},${MANAGEMENT_GLOB},${FIXED_GLOB},${FLOATING_GLOB}"
export no_proxy="${CLUSTER_NODES}${BOOTSTRAP},${VIP},${MANAGEMENT_GLOB},${FIXED_GLOB},${FLOATING_GLOB}"
pushd ${TEST_DATA_DIR}/tempest
bin/tempest --with-xunit --xunit-file=../tempest_out_$(date +%m%d%Y-%H%M%S).xml
popd
