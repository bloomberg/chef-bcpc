#!/bin/bash -e

set -x


# check that filenames and filetypes for downloads match if they don't
# match, simply exit (hence no need for faking a return code)
filecheck() {
    local VERBOSE=

    local -r FILENAME="$1"
    local    EXPECTED=""

    if [[ ! -f "$FILENAME" ]]; then
        echo "Error: $FILENAME not found" >&2
        exit 1
    fi

    FILETYPE=`file $FILENAME`

    if [[ `basename $FILENAME` == *tgz || `basename $FILENAME` == *tar.gz ]]; then
        EXPECTED="gzip compressed data"
    fi

    if [[ `basename $FILENAME` == *.deb ]]; then
        EXPECTED="Debian binary package"
    fi

    if [[ `basename $FILENAME` == *disk*img ]]; then
        EXPECTED="QEMU QCOW"
    fi

    if [[ `basename $FILENAME` =~ initrd ]]; then
        EXPECTED="data"
    fi

    if [[ `basename $FILENAME` == *.iso ]]; then
        EXPECTED="CD-ROM filesystem data"
    fi

    if [[ `basename $FILENAME` =~ vmlinuz ]]; then
        EXPECTED="Linux kernel x86 boot executable bzImage"
    fi

    if [[ -n "$EXPECTED" ]] && [[ ! "$FILETYPE" =~ "$EXPECTED" ]]; then
        echo "Error: $FILENAME is not of type $EXPECTED" >&2
        exit 1
    else
        if [[ -n "$VERBOSE" ]]; then
            if [[ -n "$EXPECTED" ]]; then
                echo "pass : expected $EXPECTED, got $FILETYPE"
            else
                echo "pass : no check implemented for $FILENAME"
            fi
        fi
    fi
}


# Define the appropriate version of each binary to grab/build
VER_KIBANA=4.0.2
# newer versions of Diamond depend upon dh-python which isn't in precise/12.04
VER_DIAMOND=f33aa2f75c6ea2dfbbc659766fe581e5bfe2476d
VER_ESPLUGIN=9c032b7c628d8da7745fbb1939dcd2db52629943

PROXY_INFO_FILE="/home/vagrant/proxy_info.sh"
if [[ -f $PROXY_INFO_FILE ]]; then
  . $PROXY_INFO_FILE
fi

# define calling gem with a proxy if necessary
if [[ -z $http_proxy ]]; then
    GEM_PROXY=""
else
    GEM_PROXY="-p $http_proxy"
fi


# we now define CURL previously in proxy_setup.sh (called from
# setup_chef_server which calls this script. Default definition is
# CURL=curl
if [ -z "$CURL" ]; then
  CURL=curl
fi


# Checked CURL
# usage: ccurl filename (new filename)
#
# The file is downloaded with default filename, checked for file type
# matching, then if a second parameter was passed, renamed to that
ccurl() {
    $CURL -L -O $1
    # filecheck will exit if a problem, otherwise it's too much noise
    set +x
    filecheck `basename $1`
    if [[ -n "$2" ]]; then
        mv `basename $1` $2
    fi
    set -x
}


DIR=`dirname $0`

mkdir -p $DIR/bins
pushd $DIR/bins/

# Install tools needed for packaging
apt-get -y install git ruby-dev make pbuilder python-mock python-configobj python-support cdbs python-all-dev python-stdeb libmysqlclient-dev libldap2-dev
if [ -z `gem list --local fpm | grep fpm | cut -f1 -d" "` ]; then
  gem install $GEM_PROXY fpm --no-ri --no-rdoc
fi

# Fetch chef client and server debs
CHEF_CLIENT_URL=https://opscode-omnibus-packages.s3.amazonaws.com/ubuntu/13.04/x86_64/chef_12.2.1-1_amd64.deb
CHEF_CLIENT_BOOTSTRAP_URL=$CHEF_CLIENT_URL
#TODO: maybe unstable url...?
# this URL requires curl -L because it will redirect
CHEF_SERVER_URL=https://web-dl.packagecloud.io/chef/stable/packages/ubuntu/trusty/chef-server-core_12.0.7-1_amd64.deb

if [ ! -f chef-client.deb ]; then
   ccurl  ${CHEF_CLIENT_URL} chef-client.deb
fi

if [ ! -f chef-client-bootstrap.deb ]; then
   $CURL -o chef-client-bootstrap.deb ${CHEF_CLIENT_BOOTSTRAP_URL}
fi

if [ ! -f chef-server.deb ]; then
   ccurl  ${CHEF_SERVER_URL} chef-server.deb
fi
FILES="chef-client.deb chef-server.deb $FILES"

KIBANA_URL=https://download.elastic.co/kibana/kibana/kibana-${VER_KIBANA}-linux-x64.tar.gz
# Build kibana 4 deb
if [ ! -f kibana_${VER_KIBANA}_amd64.deb ]; then
    ccurl ${KIBANA_URL} kibana-${VER_KIBANA}.tar.gz
    tar -zxf kibana-${VER_KIBANA}.tar.gz
    fpm -s dir -t deb --prefix /opt/kibana -n kibana -v ${VER_KIBANA} -C kibana-${VER_KIBANA}-linux-x64
    rm -rf kibana-${VER_KIBANA}-linux-x64{,.tar.gz}
fi
FILES="kibana_${VER_KIBANA}_amd64.deb $FILES"

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
        gem fetch $GEM_PROXY fluent-plugin-${i} ${VERS}
        mv fluent-plugin-${i}-*.gem fluent-plugin-${i}.gem
    fi
    FILES="fluent-plugin-${i}.gem $FILES"
done

# Fetch the cirros image for testing
if [ ! -f cirros-0.3.2-x86_64-disk.img ]; then
    ccurl http://download.cirros-cloud.net/0.3.2/cirros-0.3.2-x86_64-disk.img
fi
FILES="cirros-0.3.2-x86_64-disk.img $FILES"

# Grab the Ubuntu 14.04 installer image
if [ ! -f ubuntu-14.04-mini.iso ]; then
    $CURL -o ubuntu-14.04-mini.iso http://archive.ubuntu.com/ubuntu/dists/trusty-updates/main/installer-amd64/current/images/netboot/mini.iso
fi
FILES="ubuntu-14.04-mini.iso $FILES"

## Grab the CentOS 6 PXE boot images
#if [ ! -f centos-6-initrd.img ]; then
#    ccurl  http://mirror.net.cen.ct.gov/centos/6/os/x86_64/images/pxeboot/initrd.img centos-6-initrd.img
#fi
#FILES="centos-6-initrd.img $FILES"
#
#if [ ! -f centos-6-vmlinuz ]; then
#    ccurl  http://mirror.net.cen.ct.gov/centos/6/os/x86_64/images/pxeboot/vmlinuz centos-6-vmlinuz
#fi
#FILES="centos-6-vmlinuz $FILES"

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
    ccurl https://pypi.python.org/packages/source/p/pyrabbit/pyrabbit-1.0.1.tar.gz
fi
FILES="pyrabbit-1.0.1.tar.gz $FILES"

# Build graphite packages
GRAPHITE_CARBON_VER="0.9.13"
GRAPHITE_WHISPER_VER="0.9.13"
GRAPHITE_WEB_VER="0.9.13"
if [ ! -f python-carbon_${GRAPHITE_CARBON_VER}_all.deb ] || [ ! -f python-whisper_${GRAPHITE_WHISPER_VER}_all.deb ] || [ ! -f python-graphite-web_${GRAPHITE_WEB_VER}_all.deb ]; then
    ccurl  http://pypi.python.org/packages/source/c/carbon/carbon-${GRAPHITE_CARBON_VER}.tar.gz
    ccurl  http://pypi.python.org/packages/source/w/whisper/whisper-${GRAPHITE_WHISPER_VER}.tar.gz
    ccurl  http://pypi.python.org/packages/source/g/graphite-web/graphite-web-${GRAPHITE_WEB_VER}.tar.gz
    tar zxf carbon-${GRAPHITE_CARBON_VER}.tar.gz
    tar zxf whisper-${GRAPHITE_WHISPER_VER}.tar.gz
    tar zxf graphite-web-${GRAPHITE_WEB_VER}.tar.gz
    fpm --python-install-bin /opt/graphite/bin -s python -t deb carbon-${GRAPHITE_CARBON_VER}/setup.py
    fpm --python-install-bin /opt/graphite/bin  -s python -t deb whisper-${GRAPHITE_WHISPER_VER}/setup.py
    fpm --python-install-lib /opt/graphite/webapp -s python -t deb graphite-web-${GRAPHITE_WEB_VER}/setup.py
    rm -rf carbon-${GRAPHITE_CARBON_VER} carbon-${GRAPHITE_CARBON_VER}.tar.gz whisper-${GRAPHITE_WHISPER_VER} whisper-${GRAPHITE_WHISPER_VER}.tar.gz graphite-web-${GRAPHITE_WEB_VER} graphite-web-${GRAPHITE_WEB_VER}.tar.gz
fi
FILES="python-carbon_${GRAPHITE_CARBON_VER}_all.deb python-whisper_${GRAPHITE_WHISPER_VER}_all.deb python-graphite-web_${GRAPHITE_WEB_VER}_all.deb $FILES"

# Build the zabbix packages
if [ ! -f zabbix-agent.tar.gz ] || [ ! -f zabbix-server.tar.gz ]; then
    ccurl http://sourceforge.net/projects/zabbix/files/ZABBIX%20Latest%20Stable/2.2.2/zabbix-2.2.2.tar.gz
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

## Get some python libs
#if [ ! -f python-requests-aws_0.1.6_all.deb ]; then
#    fpm -s python -t deb -v 0.1.6 requests-aws
#fi
#FILES="python-requests-aws_0.1.6_all.deb $FILES"

# Rally has a number of dependencies. Some of the dependencies are in apt by default but some are not. Those that
# are not are built here.
RALLY_VER="0.0.4"

# We build a package for rally here but we also get the tar file of the source because it includes the samples
# directory that we want and we need a good place to run our tests from.

if [ ! -f rally.tar.gz ]; then
    ccurl https://pypi.python.org/packages/source/r/rally/rally-${RALLY_VER}.tar.gz
    tar xvf rally-${RALLY_VER}.tar.gz
    tar zcf rally.tar.gz -C rally-${RALLY_VER}/ .
    rm rally-${RALLY_VER}.tar.gz
fi

if [ ! -f rally-pip.tar.gz ] || [ ! -f rally-bin.tar.gz ]; then
    # Rally has a very large number of version specific dependencies!!
    # The latest version of PIP is installed instead of the distro version. We don't want this to block to exit on error
    # so it is changed here and reset at the end. Several apt packages must be present since easy_install builds
    # some of the dependencies.
    # Note: Once we fully switch to trusty/kilo then we should not have to patch this (hopefully).
    echo "Processing Rally setup..."
    set +x
    apt-get -y install libxml2-dev libxslt1-dev libpq-dev build-essential libssl-dev libffi-dev python-dev python-pip

    # Note: This will create a pip package with the newest version
    fpm -s python -t deb -f -v 6.1.1 pip

    # We don't need the newest version installed here at this time but if we need other pip options then we may.
    # dpkg -i python-pip_6.1.1_all.deb

    # We install rally and a few other items here. Since fpm does not resolve dependencies but only lists them, we
    # have to force an install and then tar up the dist-packages and local/bin
    pip install rally --default-timeout 60 -I
    pip install python-openstackclient --default-timeout 60
    pip install -U argparse
    pip install -U setuptools

    tar zcf rally-pip.tar.gz -C /usr/local/lib/python2.7/dist-packages .
    tar zcf rally-bin.tar.gz --exclude="fpm" --exclude="ruby*" -C /usr/local/bin .
    set -x
fi

# Rally has a number of dependencies. Some of the dependencies are in apt by default but some are not. Those that
# are not are built here.
RALLY_VER="0.0.4"

# We build a package for rally here but we also get the tar file of the source because it includes the samples
# directory that we want and we need a good place to run our tests from.

if [ ! -f rally.tar.gz ]; then
    ccurl https://pypi.python.org/packages/source/r/rally/rally-${RALLY_VER}.tar.gz
    tar xvf rally-${RALLY_VER}.tar.gz
    tar zcf rally.tar.gz -C rally-${RALLY_VER}/ .
    rm rally-${RALLY_VER}.tar.gz
fi

if [ ! -f rally-pip.tar.gz ] || [ ! -f rally-bin.tar.gz ]; then
    # Rally has a very large number of version specific dependencies!!
    # The latest version of PIP is installed instead of the distro version. We don't want this to block to exit on error
    # so it is changed here and reset at the end. Several apt packages must be present since easy_install builds
    # some of the dependencies.
    # Note: Once we fully switch to trusty/kilo then we should not have to patch this (hopefully).
    echo "Processing Rally setup..."
    set +x
    apt-get -y install libxml2-dev libxslt1-dev libpq-dev build-essential libssl-dev libffi-dev python-dev python-pip

    # Note: This will create a pip package with the newest version
    fpm -s python -t deb -f -v 6.1.1 pip

    # We don't need the newest version installed here at this time but if we need other pip options then we may.
    # dpkg -i python-pip_6.1.1_all.deb

    # We install rally and a few other items here. Since fpm does not resolve dependencies but only lists them, we
    # have to force an install and then tar up the dist-packages and local/bin
    pip install rally --default-timeout 60 -I
    pip install python-openstackclient --default-timeout 60
    pip install -U argparse
    pip install -U setuptools

    tar zcf rally-pip.tar.gz -C /usr/local/lib/python2.7/dist-packages .
    tar zcf rally-bin.tar.gz --exclude="fpm" --exclude="ruby*" -C /usr/local/bin .
    set -x
fi

FILES="rally.tar.gz rally-pip.tar.gz rally-bin.tar.gz python-pip_6.1.1_all.deb $FILES"

# End of Rally

popd
