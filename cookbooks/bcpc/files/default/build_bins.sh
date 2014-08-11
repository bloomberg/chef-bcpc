#!/bin/bash -e

set -x

# Define the appropriate version of each binary to grab/build
VER_KIBANA=2581d314f12f520638382d23ffc03977f481c1e4
# newer versions of Diamond depend upon dh-python which isn't in precise/12.04
VER_DIAMOND=f33aa2f75c6ea2dfbbc659766fe581e5bfe2476d
VER_ESPLUGIN=9c032b7c628d8da7745fbb1939dcd2db52629943

if [[ -f ./proxy_setup.sh ]]; then
  . ./proxy_setup.sh
fi


# we now define CURL previously in proxy_setup.sh (called from
# setup_chef_server which calls this script. Default definition is
# CURL=curl
if [ -z "$CURL" ]; then
  CURL=curl
fi

DIR=`dirname $0`

mkdir -p $DIR/bins
pushd $DIR/bins/

# Install tools needed for packaging
apt-get -y install git rubygems make pbuilder python-mock python-configobj python-support cdbs python-all-dev python-stdeb libmysqlclient-dev libldap2-dev python-pip
if [ -z `gem list --local fpm | grep fpm | cut -f1 -d" "` ]; then
  gem install fpm --no-ri --no-rdoc
fi

# Fetch chef client and server debs
CHEF_CLIENT_URL=https://opscode-omnibus-packages.s3.amazonaws.com/ubuntu/12.04/x86_64/chef_10.32.2-1_amd64.deb
#CHEF_CLIENT_URL=https://opscode-omnibus-packages.s3.amazonaws.com/ubuntu/12.04/x86_64/chef_11.10.4-1.ubuntu.12.04_amd64.deb
CHEF_SERVER_URL=https://opscode-omnibus-packages.s3.amazonaws.com/ubuntu/12.04/x86_64/chef-server_11.0.12-1.ubuntu.12.04_amd64.deb
if [ ! -f chef-client.deb ]; then
   $CURL -o chef-client.deb ${CHEF_CLIENT_URL}
fi

if [ ! -f chef-server.deb ]; then
   $CURL -o chef-server.deb ${CHEF_SERVER_URL}
fi
FILES="chef-client.deb chef-server.deb $FILES"

# Build kibana3 installable bundle
if [ ! -f kibana3.tgz ]; then
    git clone https://github.com/elasticsearch/kibana.git kibana3
    cd kibana3/src
    git archive --output ../../kibana3.tgz --prefix kibana3/ $VER_KIBANA
    cd ../..
    rm -rf kibana3
fi
FILES="kibana3.tgz $FILES"

# any pegged gem versions
REV_elasticsearch="0.2.0"

# Grab plugins for fluentd
for i in elasticsearch tail-multiline tail-ex record-reformer rewrite; do
    if [ ! -f fluent-plugin-${i}.gem ]; then
        PEG=REV_${i}
        if [[ ! -z ${!PEG} ]]; then
            VERS="-v ${!PEG}"
        else
            VERS=""
        fi
        gem fetch fluent-plugin-${i} ${VERS}
        mv fluent-plugin-${i}-*.gem fluent-plugin-${i}.gem
    fi
    FILES="fluent-plugin-${i}.gem $FILES"
done

# Fetch the cirros image for testing
if [ ! -f cirros-0.3.2-x86_64-disk.img ]; then
    $CURL -O -L http://download.cirros-cloud.net/0.3.2/cirros-0.3.2-x86_64-disk.img
fi
FILES="cirros-0.3.2-x86_64-disk.img $FILES"

# Grab the Ubuntu 12.04 installer image
if [ ! -f ubuntu-12.04-mini.iso ]; then
    # Download this ISO to get the latest kernel/X LTS stack installer
    #$CURL -o ubuntu-12.04-mini.iso http://archive.ubuntu.com/ubuntu/dists/precise-updates/main/installer-amd64/current/images/raring-netboot/mini.iso
    $CURL -o ubuntu-12.04-mini.iso http://archive.ubuntu.com/ubuntu/dists/precise/main/installer-amd64/current/images/netboot/mini.iso
fi
FILES="ubuntu-12.04-mini.iso $FILES"

# Grab the CentOS 6 PXE boot images
if [ ! -f centos-6-initrd.img ]; then
    #$CURL -o centos-6-mini.iso http://mirror.net.cen.ct.gov/centos/6/isos/x86_64/CentOS-6.4-x86_64-netinstall.iso
    $CURL -o centos-6-initrd.img http://mirror.net.cen.ct.gov/centos/6/os/x86_64/images/pxeboot/initrd.img
fi
FILES="centos-6-initrd.img $FILES"

if [ ! -f centos-6-vmlinuz ]; then
    $CURL -o centos-6-vmlinuz http://mirror.net.cen.ct.gov/centos/6/os/x86_64/images/pxeboot/vmlinuz
fi
FILES="centos-6-vmlinuz $FILES"

# Make the diamond package
if [ ! -f diamond.deb ]; then
    git clone https://github.com/BrightcoveOS/Diamond.git
    cd Diamond
    git checkout $VER_DIAMOND
    make builddeb
    VERSION=`cat version.txt`
    cd ..
    mv Diamond/build/diamond_${VERSION}_all.deb diamond.deb
    rm -rf Diamond
fi
FILES="diamond.deb $FILES"

# Snag elasticsearch
ES_VER=1.1.1
if [ ! -f elasticsearch-${ES_VER}.deb ]; then
    $CURL -O -L https://download.elasticsearch.org/elasticsearch/elasticsearch/elasticsearch-${ES_VER}.deb
fi
if [ ! -f elasticsearch-${ES_VER}.deb.sha1.txt ]; then
    $CURL -O -L https://download.elasticsearch.org/elasticsearch/elasticsearch/elasticsearch-${ES_VER}.deb.sha1.txt
fi
if [[ `shasum elasticsearch-${ES_VER}.deb` != `cat elasticsearch-${ES_VER}.deb.sha1.txt` ]]; then
    echo "SHA mismatch detected for elasticsearch ${ES_VER}!"
    echo "Have: `shasum elasticsearch-${ES_VER}.deb`"
    echo "Expected: `cat elasticsearch-${ES_VER}.deb.sha1.txt`"
    exit 1
fi

FILES="elasticsearch-${ES_VER}.deb elasticsearch-${ES_VER}.deb.sha1.txt $FILES"

if [ ! -f elasticsearch-plugins.tgz ]; then
    git clone https://github.com/mobz/elasticsearch-head.git
    cd elasticsearch-head
    git archive --output ../elasticsearch-plugins.tgz --prefix head/_site/ $VER_ESPLUGIN
    cd ..
    rm -rf elasticsearch-head
fi
FILES="elasticsearch-plugins.tgz $FILES"

# Fetch pyrabbit
if [ ! -f pyrabbit-1.0.1.tar.gz ]; then
    $CURL -O -L https://pypi.python.org/packages/source/p/pyrabbit/pyrabbit-1.0.1.tar.gz
fi
FILES="pyrabbit-1.0.1.tar.gz $FILES"

# Build graphite packages
if [ ! -f python-carbon_0.9.12_all.deb ] || [ ! -f python-whisper_0.9.12_all.deb ] || [ ! -f python-graphite-web_0.9.12_all.deb ]; then
    $CURL -L -O http://pypi.python.org/packages/source/c/carbon/carbon-0.9.12.tar.gz
    $CURL -L -O http://pypi.python.org/packages/source/w/whisper/whisper-0.9.12.tar.gz
    $CURL -L -O http://pypi.python.org/packages/source/g/graphite-web/graphite-web-0.9.12.tar.gz
    tar zxf carbon-0.9.12.tar.gz
    tar zxf whisper-0.9.12.tar.gz
    tar zxf graphite-web-0.9.12.tar.gz
    fpm --python-install-bin /opt/graphite/bin -s python -t deb carbon-0.9.12/setup.py
    fpm --python-install-bin /opt/graphite/bin  -s python -t deb whisper-0.9.12/setup.py
    fpm --python-install-lib /opt/graphite/webapp -s python -t deb graphite-web-0.9.12/setup.py
    rm -rf carbon-0.9.12 carbon-0.9.12.tar.gz whisper-0.9.12 whisper-0.9.12.tar.gz graphite-web-0.9.12 graphite-web-0.9.12.tar.gz
fi
FILES="python-carbon_0.9.12_all.deb python-whisper_0.9.12_all.deb python-graphite-web_0.9.12_all.deb $FILES"

# Build the zabbix packages
if [ ! -f zabbix-agent.tar.gz ] || [ ! -f zabbix-server.tar.gz ]; then
    $CURL -L -O http://sourceforge.net/projects/zabbix/files/ZABBIX%20Latest%20Stable/2.2.2/zabbix-2.2.2.tar.gz
    tar zxf zabbix-2.2.2.tar.gz
    rm -rf /tmp/zabbix-install && mkdir -p /tmp/zabbix-install
    cd zabbix-2.2.2
    ./configure --prefix=/tmp/zabbix-install --enable-agent --with-ldap
    make install
    tar zcf zabbix-agent.tar.gz -C /tmp/zabbix-install .
    rm -rf /tmp/zabbix-install && mkdir -p /tmp/zabbix-install
    ./configure --prefix=/tmp/zabbix-install --enable-server --with-mysql --with-ldap
    make install
    cp -a frontends/php /tmp/zabbix-install/share/zabbix/
    cp database/mysql/* /tmp/zabbix-install/share/zabbix/
    tar zcf zabbix-server.tar.gz -C /tmp/zabbix-install .
    rm -rf /tmp/zabbix-install
    cd ..
    cp zabbix-2.2.2/zabbix-agent.tar.gz .
    cp zabbix-2.2.2/zabbix-server.tar.gz .
    rm -rf zabbix-2.2.2 zabbix-2.2.2.tar.gz
fi
FILES="zabbix-agent.tar.gz zabbix-server.tar.gz $FILES"

# upgrade pip
if [ "`pip --version | cut -d " " -f 2`" == "1.0" ]; then
    pip install --upgrade pip
    hash pip
fi
PIPDIR="pip-packages"
# Get pip packages
if [ ! -e $PIPDIR ]; then
    mkdir $PIPDIR
fi
for package in requests-aws==0.1.5 "httplib2>=0.7.5" http://tarballs.openstack.org/sahara/sahara-stable-icehouse.tar.gz sahara-dashboard python-saharaclient; do
    pip --cert cacert.pem install --no-use-wheel --upgrade -d $PIPDIR $package
done
FILES="$PIPDIR $FILES"

popd
