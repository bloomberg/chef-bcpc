#!/bin/bash
# Exit immediately if anything goes wrong, instead of making things worse.
set -e

if [[ ! -z $BOOTSTRAP_HTTP_PROXY ]] || [[ ! -z $BOOTSTRAP_HTTPS_PROXY ]] ; then
  echo "Testing configured proxies..."
  source $REPO_ROOT/bootstrap/shared/shared_proxy_setup.sh
fi

REQUIRED_VARS=( BOOTSTRAP_CACHE_DIR REPO_ROOT )
check_for_envvars ${REQUIRED_VARS[@]}

# Create directory for download cache.
mkdir -p $BOOTSTRAP_CACHE_DIR

# download_file wraps the usual behavior of curling a remote URL to a local file
download_file() {
  FILE=$1
  URL=$2

  if [[ ! -f $BOOTSTRAP_CACHE_DIR/$FILE && ! -f $BOOTSTRAP_CACHE_DIR/${FILE}_downloaded ]]; then
    echo $FILE
    rm -f $BOOTSTRAP_CACHE_DIR/$FILE
    curl -L --progress-bar -o $BOOTSTRAP_CACHE_DIR/$FILE $URL
    touch $BOOTSTRAP_CACHE_DIR/${FILE}_downloaded
  fi
}

# This uses ROM-o-Matic to generate a custom PXE boot ROM.
# (doesn't use the function because of the unique curl command)
ROM=gpxe-1.0.1-80861004.rom
if [[ ! -f $BOOTSTRAP_CACHE_DIR/$ROM && ! -f $BOOTSTRAP_CACHE_DIR/${ROM}_downloaded ]]; then
  echo $ROM
  rm -f $BOOTSTRAP_CACHE_DIR/$ROM
  curl -L --progress-bar -o $BOOTSTRAP_CACHE_DIR/$ROM "http://rom-o-matic.net/gpxe/gpxe-1.0.1/contrib/rom-o-matic/build.php" -H "Origin: http://rom-o-matic.net" -H "Host: rom-o-matic.net" -H "Content-Type: application/x-www-form-urlencoded" -H "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8" -H "Referer: http://rom-o-matic.net/gpxe/gpxe-1.0.1/contrib/rom-o-matic/build.php" -H "Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.3" --data "version=1.0.1&use_flags=1&ofmt=ROM+binary+%28flashable%29+image+%28.rom%29&nic=all-drivers&pci_vendor_code=8086&pci_device_code=1004&PRODUCT_NAME=&PRODUCT_SHORT_NAME=gPXE&CONSOLE_PCBIOS=on&BANNER_TIMEOUT=20&NET_PROTO_IPV4=on&COMCONSOLE=0x3F8&COMSPEED=115200&COMDATA=8&COMPARITY=0&COMSTOP=1&DOWNLOAD_PROTO_TFTP=on&DNS_RESOLVER=on&NMB_RESOLVER=off&IMAGE_ELF=on&IMAGE_NBI=on&IMAGE_MULTIBOOT=on&IMAGE_PXE=on&IMAGE_SCRIPT=on&IMAGE_BZIMAGE=on&IMAGE_COMBOOT=on&AUTOBOOT_CMD=on&NVO_CMD=on&CONFIG_CMD=on&IFMGMT_CMD=on&IWMGMT_CMD=on&ROUTE_CMD=on&IMAGE_CMD=on&DHCP_CMD=on&SANBOOT_CMD=on&LOGIN_CMD=on&embedded_script=&A=Get+Image"
  touch $BOOTSTRAP_CACHE_DIR/${ROM}_downloaded
fi

# Obtain an Ubuntu netboot image to be used for PXE booting.
download_file ubuntu-14.04-mini.iso http://archive.ubuntu.com/ubuntu/dists/trusty-updates/main/installer-amd64/current/images/netboot/mini.iso

# Obtain a Vagrant Trusty box.
BOX=trusty-server-cloudimg-amd64-vagrant-disk1.box
download_file $BOX http://cloud-images.ubuntu.com/vagrant/trusty/current/$BOX

# Obtain Chef client and server DEBs.
CHEF_CLIENT_DEB=chef_12.3.0-1_amd64.deb
CHEF_SERVER_DEB=chef-server-core_12.0.8-1_amd64.deb
download_file $CHEF_CLIENT_DEB https://opscode-omnibus-packages.s3.amazonaws.com/ubuntu/10.04/x86_64/$CHEF_CLIENT_DEB
download_file $CHEF_SERVER_DEB https://web-dl.packagecloud.io/chef/stable/packages/ubuntu/trusty/$CHEF_SERVER_DEB

# Get newer cookbooks for R6 from the Chef Supermarket.
mkdir -p $BOOTSTRAP_CACHE_DIR/cookbooks-r6
download_file cookbooks-r6/ntp-1.8.6.tar.gz http://cookbooks.opscode.com/api/v1/cookbooks/ntp/versions/1.8.6/download
download_file cookbooks-r6/chef-client-4.3.1.tar.gz http://cookbooks.opscode.com/api/v1/cookbooks/chef-client/versions/4.3.1/download
download_file cookbooks-r6/apt-2.7.0.tar.gz http://cookbooks.opscode.com/api/v1/cookbooks/apt/versions/2.7.0/download
download_file cookbooks-r6/logrotate-1.9.2.tar.gz http://cookbooks.opscode.com/api/v1/cookbooks/logrotate/versions/1.9.2/download
download_file cookbooks-r6/cron-1.6.1.tar.gz http://cookbooks.opscode.com/api/v1/cookbooks/cron/versions/1.6.1/download
download_file cookbooks-r6/windows-1.38.1.tar.gz http://cookbooks.opscode.com/api/v1/cookbooks/windows/versions/1.38.1/download
download_file cookbooks-r6/chef_handler-1.2.0.tar.gz http://cookbooks.opscode.com/api/v1/cookbooks/chef_handler/versions/1.2.0/download
download_file cookbooks-r6/ubuntu-1.1.8.tar.gz http://cookbooks.opscode.com/api/v1/cookbooks/ubuntu/versions/1.1.8/download
download_file cookbooks-r6/hostsfile-2.4.5.tar.gz https://supermarket.chef.io/api/v1/cookbooks/hostsfile/versions/2.4.5/download
download_file cookbooks-r6/concat-0.3.0.tar.gz https://supermarket.chef.io/api/v1/cookbooks/concat/versions/0.3.0/download

# Pull knife-acl gem.
download_file knife-acl-0.0.12.gem https://rubygems.global.ssl.fastly.net/gems/knife-acl-0.0.12.gem

# Pull needed gems for fpm.
GEMS=( arr-pm-0.0.10 backports-3.6.4 cabin-0.7.1 childprocess-0.5.6 clamp-0.6.5 ffi-1.9.8
       fpm-1.3.3 json-1.8.2 )
mkdir -p $BOOTSTRAP_CACHE_DIR/fpm_gems
for GEM in ${GEMS[@]}; do
  download_file fpm_gems/$GEM.gem https://rubygems.global.ssl.fastly.net/gems/$GEM.gem
done

# Pull needed gems for fluentd.
GEMS=( excon-0.45.3
       multi_json-1.11.2 multipart-post-2.0.0 faraday-0.9.1
       elasticsearch-api-1.0.12 elasticsearch-transport-1.0.12
       elasticsearch-1.0.12 fluent-plugin-elasticsearch-0.9.0 )
mkdir -p $BOOTSTRAP_CACHE_DIR/fluentd_gems
for GEM in ${GEMS[@]}; do
  download_file fluentd_gems/$GEM.gem https://rubygems.global.ssl.fastly.net/gems/$GEM.gem
done

# Obtain Cirros image.
download_file cirros-0.3.4-x86_64-disk.img http://download.cirros-cloud.net/0.3.4/cirros-0.3.4-x86_64-disk.img

# Obtain various items used for monitoring.
# Remove obsolete kibana package
rm -f $BOOTSTRAP_CACHE_DIR/kibana-4.0.2-linux-x64.tar.gz_downloaded $BOOTSTRAP_CACHE_DIR/kibana-4.0.2-linux-x64.tar.gz
# Remove obsolete cached items for BrightCoveOS Diamond
rm -rf $BOOTSTRAP_CACHE_DIR/diamond_downloaded $BOOTSTRAP_CACHE_DIR/diamond
# unfortunately GitHub ZIP files do not contain the actual Git index, so we must use Git to clone here
if [[ ! -f $BOOTSTRAP_CACHE_DIR/python-diamond_downloaded ]]; then
  git clone https://github.com/python-diamond/Diamond $BOOTSTRAP_CACHE_DIR/python-diamond
  touch $BOOTSTRAP_CACHE_DIR/python-diamond_downloaded
fi
if [[ ! -f $BOOTSTRAP_CACHE_DIR/elasticsearch-head_downloaded ]]; then
  git clone https://github.com/mobz/elasticsearch-head $BOOTSTRAP_CACHE_DIR/elasticsearch-head
  touch $BOOTSTRAP_CACHE_DIR/elasticsearch-head_downloaded
fi

download_file pyrabbit-1.0.1.tar.gz https://pypi.python.org/packages/source/p/pyrabbit/pyrabbit-1.0.1.tar.gz
download_file requests-aws-0.1.6.tar.gz https://pypi.python.org/packages/source/r/requests-aws/requests-aws-0.1.6.tar.gz
download_file pyzabbix-0.7.3.tar.gz https://pypi.python.org/packages/source/p/pyzabbix/pyzabbix-0.7.3.tar.gz
download_file pagerduty-zabbix-proxy.py https://gist.githubusercontent.com/ryanhoskin/202a1497c97b0072a83a/raw/96e54cecdd78e7990bb2a6cc8f84070599bdaf06/pd-zabbix-proxy.py

download_file carbon-0.9.13.tar.gz http://pypi.python.org/packages/source/c/carbon/carbon-0.9.13.tar.gz
download_file whisper-0.9.13.tar.gz http://pypi.python.org/packages/source/w/whisper/whisper-0.9.13.tar.gz
download_file graphite-web-0.9.13.tar.gz http://pypi.python.org/packages/source/g/graphite-web/graphite-web-0.9.13.tar.gz

# Obtain packages for Rally. There are a lot.
# for future reference, to install files from this cache use pip install --no-index -f file:///path/to/files rally
RALLY_PACKAGES=( Babel-1.3.tar.gz
Jinja2-2.7.3.tar.gz
Mako-1.0.1.tar.gz
MarkupSafe-0.23.tar.gz
PyYAML-3.11.tar.gz
Pygments-2.0.2.tar.gz
SQLAlchemy-0.9.9.tar.gz
Sphinx-1.2.3.tar.gz
Tempita-0.5.2.tar.gz
alembic-0.7.6.tar.gz
anyjson-0.3.3.tar.gz
appdirs-1.4.0.tar.gz
argparse-1.3.0.tar.gz
boto-2.38.0.tar.gz
cffi-1.1.0.tar.gz
cliff-1.12.0.tar.gz
cliff-tablib-1.1.tar.gz
cmd2-0.6.8.tar.gz
cryptography-0.9.tar.gz
debtcollector-0.4.0.tar.gz
decorator-3.4.2.tar.gz
docutils-0.12.tar.gz
ecdsa-0.13.tar.gz
enum34-1.0.4.tar.gz
extras-0.0.3.tar.gz
fixtures-1.2.0.tar.gz
futures-3.0.2.tar.gz
httplib2-0.9.1.tar.gz
idna-2.0.tar.gz
ipaddress-1.0.7.tar.gz
iso8601-0.1.10.tar.gz
jsonpatch-1.11.tar.gz
jsonpointer-1.9.tar.gz
jsonschema-2.4.0.tar.gz
linecache2-1.0.0.tar.gz
lxml-3.4.4.tar.gz
msgpack-python-0.4.6.tar.gz
netaddr-0.7.14.tar.gz
netifaces-0.10.4.tar.gz
ordereddict-1.1.tar.gz
os-client-config-1.2.0.tar.gz
oslo.config-1.11.0.tar.gz
oslo.context-0.3.0.tar.gz
oslo.db-1.9.0.tar.gz
oslo.i18n-1.6.0.tar.gz
oslo.log-1.2.0.tar.gz
oslo.serialization-1.5.0.tar.gz
oslo.utils-1.5.0.tar.gz
paramiko-1.15.2.tar.gz
pbr-1.0.1.tar.gz
pip-7.0.3.tar.gz
psycopg2-2.6.tar.gz
pyOpenSSL-0.15.1.tar.gz
pyasn1-0.1.7.tar.gz
pycparser-2.13.tar.gz
pycrypto-2.6.1.tar.gz
pyparsing-2.0.3.tar.gz
python-ceilometerclient-1.2.0.tar.gz
python-cinderclient-1.2.1.tar.gz
python-designateclient-1.2.0.tar.gz
python-glanceclient-0.18.0.tar.gz
python-heatclient-0.6.0.tar.gz
python-ironicclient-0.6.0.tar.gz
python-keystoneclient-1.5.0.tar.gz
python-mimeparse-0.1.4.tar.gz
python-neutronclient-2.5.0.tar.gz
python-novaclient-2.25.0.tar.gz
python-openstackclient-1.3.0.tar.gz
python-saharaclient-0.9.0.tar.gz
python-subunit-1.1.0.tar.gz
python-swiftclient-2.4.0.tar.gz
python-troveclient-1.1.0.tar.gz
python-zaqarclient-0.1.1.tar.gz
pytz-2015.4.tar.gz
rally-0.0.4.tar.gz
requests-2.7.0.tar.gz
setuptools-17.0.tar.gz
simplejson-3.7.2.tar.gz
six-1.9.0.tar.gz
sqlalchemy-migrate-0.9.6.tar.gz
sqlparse-0.1.15.tar.gz
stevedore-1.4.0.tar.gz
tablib-0.10.0.tar.gz
testresources-0.2.7.tar.gz
testscenarios-0.5.0.tar.gz
testtools-1.8.0.tar.gz
traceback2-1.4.0.tar.gz
unittest2-1.0.1.tar.gz
warlock-1.1.0.tar.gz
wrapt-1.10.4.tar.gz )

# if on OS X, use BSD sed, otherwise assume GNU sed
if [[ $(uname) == "Darwin" ]]; then SED="sed -E"; else SED="sed -r"; fi
mkdir -p $BOOTSTRAP_CACHE_DIR/rally
for RALLY_PACKAGE in ${RALLY_PACKAGES[@]}; do
  BARE_PACKAGE_NAME=$(echo $RALLY_PACKAGE | $SED 's/^(.+)-.+$/\1/')
  download_file rally/$RALLY_PACKAGE https://pypi.python.org/packages/source/$(echo $RALLY_PACKAGE | cut -c1 -)/$BARE_PACKAGE_NAME/$RALLY_PACKAGE
done

# ..and for the one package that has to be a special snowflake and not fit into
# the above scheme because of capitalization weirdness
download_file rally/prettytable-0.7.2.tar.gz https://pypi.python.org/packages/source/P/PrettyTable/prettytable-0.7.2.tar.gz
