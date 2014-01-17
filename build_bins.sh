#!/bin/bash 

set -e
set -x

# Define the appropriate version of each binary to grab/build
VER_KIBANA=d1495fbf6e9c20c707ecd4a77444e1d486a1e7d6
VER_DIAMOND=d64cc5cbae8bee93ef444e6fa41b4456f89c6e12
VER_ESPLUGIN=c3635657f4bb5eca0d50afa8545ceb5da8ca223a

# The proxy and $CURL will be needed later
if [[ -f ./proxy_setup.sh ]]; then
  . ./proxy_setup.sh
fi

if [[ -z "$CURL" ]]; then
  echo "CURL is not defined"
  exit
fi

DIR=`dirname $0`

mkdir -p $DIR/bins
pushd $DIR/bins/
mkdir -p python

# serve the files if nothing else is doing so already
netstat -nlt4 | grep -q ':8080' || nohup python -m SimpleHTTPServer 8080 > ../python_server.log 2>&1 &
# wait for python to come-up (as we may need it during apt-get update)
sleep 5

# Get up to date
apt-get -y update

# Install tools needed for packaging
apt-get -y install git rubygems make pbuilder python-mock python-configobj python-support cdbs python-all-dev python-stdeb libmysqlclient-dev libldap2-dev ruby-dev gcc patch rake ruby1.9.3 ruby1.9.1-dev python-pip python-setuptools dpkg-dev apt-utils haveged
if [ -z `gem list --local fpm | grep fpm | cut -f1 -d" "` ]; then
  gem install fpm --no-ri --no-rdoc
fi

RUBY19=ruby1.9.3
RUBY18=ruby1.8
GEM19=gem1.9.1
GEM18=gem1.8
RUBY19_ver=$($RUBY19 -e "print RUBY_VERSION")
RUBY18_ver=$(ruby -e "print RUBY_VERSION")

# need to use gem-compile for gems with native code
# provide a Ruby 1.9.1 and Ruby 1.8 gem-compile capable RubyGem
if ! ${RUBY19_ver}_gem_compile/bin/$GEM19 list --local gem-compiler | grep -q gem-compiler || \
   ! ${RUBY18_ver}_gem_compile/bin/$GEM18 list --local gem-compiler | grep -q gem-compiler; then
  # need a RubyGems > 1.8.25 for gem-compile (not available via apt-get)
  $CURL -O http://production.cf.rubygems.org/rubygems/rubygems-update-1.8.29.gem
  gem unpack rubygems-update-1.8.29.gem
  pushd rubygems*
  $RUBY18 setup.rb --prefix `pwd`/../${RUBY18_ver}_gem_compile
  $RUBY19 setup.rb --prefix `pwd`/../${RUBY19_ver}_gem_compile
  popd
  export RUBYLIB=`pwd`/${RUBY18_ver}_gem_compile/lib
  `pwd`/${RUBY18_ver}_gem_compile/bin/$GEM18 install gem-compile
  export RUBYLIB=`pwd`/${RUBY19_ver}_gem_compile/lib
  `pwd`/${RUBY19_ver}_gem_compile/bin/$GEM19 install gem-compile
  unset RUBYLIB
fi

# Build kibana3 installable bundle
if [ ! -f kibana3.tgz ]; then
    git clone https://github.com/elasticsearch/kibana.git kibana3
    cd kibana3
    git archive --output ../kibana3.tgz --prefix kibana3/ $VER_KIBANA
    cd ..
    rm -rf kibana3
fi
FILES="kibana3.tgz $FILES"

# Grab plugins for fluentd
for i in elasticsearch tail-multiline tail-ex record-reformer rewrite; do
    if [[ ! -f fluent-plugin-${i}*.gem && ! -f gems/fluent-plugin-${i}*.gem ]]; then
        gem fetch fluent-plugin-${i}
        ln -s fluent-plugin-${i}-*.gem fluent-plugin-${i}.gem || true
    fi
    FILES="fluent-plugin-${i}*.gem $FILES"
done

# Get the Rubygem for zookeeper
if [[ ! -f zookeeper*.gem && ! -f gems/zookeeper*.gem ]]; then
    gem fetch zookeeper -v 1.4.7
    ln -s zookeeper-*.gem zookeeper.gem || true
fi
FILES="zookeeper*.gem $FILES"

# Fetch the cirros image for testing
if [ ! -f cirros-0.3.0-x86_64-disk.img ]; then
    $CURL -O -L https://launchpad.net/cirros/trunk/0.3.0/+download/cirros-0.3.0-x86_64-disk.img
fi
FILES="cirros-0.3.0-x86_64-disk.img $FILES"

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
if [ ! -f diamond*.deb ]; then
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
if [ ! -f elasticsearch-0.90.3.deb ]; then
    $CURL -O -L https://download.elasticsearch.org/elasticsearch/elasticsearch/elasticsearch-0.90.3.deb
fi
FILES="elasticsearch-0.90.3.deb $FILES"

if [ ! -f elasticsearch-plugins.tgz ]; then
    git clone https://github.com/mobz/elasticsearch-head.git
    cd elasticsearch-head
    git archive --output ../elasticsearch-plugins.tgz --prefix head/_site/ $VER_ESPLUGIN
    cd ..
    rm -rf elasticsearch-head
fi
FILES="elasticsearch-plugins.tgz $FILES"

# Fetch pyrabbit
if [ ! -f python/pyrabbit-1.0.1.tar.gz ]; then
    while ! $(file python/pyrabbit-1.0.1.tar.gz | grep -q 'gzip compressed data'); do
        (cd python && $CURL -O -L http://pypi.python.org/packages/source/p/pyrabbit/pyrabbit-1.0.1.tar.gz)
    done
fi
FILES="pyrabbit-1.0.1.tar.gz $FILES"

# Build graphite packages
if [ ! -f python-carbon_0.9.10_all.deb ] || [ ! -f python-whisper_0.9.10_all.deb ] || [ ! -f python-graphite-web_0.9.10_all.deb ]; then
    while ! $(file carbon-0.9.10.tar.gz | grep -q 'gzip compressed data'); do
        $CURL -L -O http://pypi.python.org/packages/source/c/carbon/carbon-0.9.10.tar.gz
    done
    while ! $(file whisper-0.9.10.tar.gz | grep -q 'gzip compressed data'); do
        $CURL -L -O http://pypi.python.org/packages/source/w/whisper/whisper-0.9.10.tar.gz
    done
    while ! $(file graphite-web-0.9.10.tar.gz | grep -q 'gzip compressed data'); do
        $CURL -L -O http://pypi.python.org/packages/source/g/graphite-web/graphite-web-0.9.10.tar.gz
    done
    tar zxf carbon-0.9.10.tar.gz
    tar zxf whisper-0.9.10.tar.gz
    tar zxf graphite-web-0.9.10.tar.gz
    fpm --python-install-bin /opt/graphite/bin -s python -t deb carbon-0.9.10/setup.py
    fpm --python-install-bin /opt/graphite/bin  -s python -t deb whisper-0.9.10/setup.py
    fpm --python-install-lib /opt/graphite/webapp -s python -t deb graphite-web-0.9.10/setup.py
fi
FILES="python-carbon_0.9.10_all.deb python-whisper_0.9.10_all.deb python-graphite-web_0.9.10_all.deb $FILES"

# Download Python requests-aws for Zabbix monitoring
if [ ! -f python-requests-aws_0.1.5_all.deb ]; then
    fpm -s python -t deb -v 0.1.5 requests-aws
fi
FILES="python-requests-aws_0.1.5_all.deb $FILES"

# Build the zabbix packages
if [ ! -f zabbix-agent.tar.gz ] || [ ! -f zabbix-server.tar.gz ]; then
    $CURL -L -O http://sourceforge.net/projects/zabbix/files/ZABBIX%20Latest%20Stable/2.0.7/zabbix-2.0.7.tar.gz
    tar zxf zabbix-2.0.7.tar.gz
    rm -rf /tmp/zabbix-install && mkdir -p /tmp/zabbix-install
    cd zabbix-2.0.7
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
    cp zabbix-2.0.7/zabbix-agent.tar.gz .
    cp zabbix-2.0.7/zabbix-server.tar.gz .
    rm -rf zabbix-2.0.7 zabbix-2.0.7.tar.gz
fi
FILES="zabbix-agent.tar.gz zabbix-server.tar.gz $FILES"

# Gather the Chef packages and provide a dpkg repo
opscode_urls="https://opscode-omnibus-packages.s3.amazonaws.com/ubuntu/12.04/x86_64/chef_11.8.0-1.ubuntu.12.04_amd64.deb
https://opscode-omnibus-packages.s3.amazonaws.com/ubuntu/12.04/x86_64/chef-server_11.0.8-1.ubuntu.12.04_amd64.deb"
for url in $opscode_urls; do
    if [ ! -f $(basename $url) ]; then
        $CURL -L -O $url
    fi
done

# need a key to sign repo
if [[ ! -f ${HOME}/apt_key.sec || ! -f apt_key.pub ]]; then
  rm -rf ${HOME}/apt_key.sec apt_key.pub
  gpg --batch --gen-key << EOF
    Key-Type: DSA
    Key-Length: 1024
    Key-Usage: sign
    Name-Real: Local BCPC Repo
    Name-Comment: For dpkg repo signing
    Expire-Date: 0
    %pubring apt_key.pub
    %secring ${HOME}/apt_key.sec
    %commit
EOF
  chmod 700 ${HOME}/apt_key.sec
fi

###################
# generate apt-repo
dpkg-scanpackages . > Packages
gzip -c Packages > Packages.gz
apt-ftparchive release . > Release
rm -f Release.gpg
gpg -abs --keyring ./apt_key.pub --secret-keyring ${HOME}/apt_key.sec -o Release.gpg Release

####################
# generate Pypi repo

# Wheel installs require setuptools >= 0.8 for dist-info support.
# can then follow http://askubuntu.com/questions/399446
# but can't upgrade setuptools first as:
# "/usr/bin/pip install: error: no such option: --no-use-wheel"
/usr/bin/pip install pip2pi || /bin/true
/usr/local/bin/pip install setuptools --no-use-wheel --upgrade
/usr/local/bin/pip install pip2pi 
dir2pi python

#########################
# generate rubygems repos

# need the builder gem to generate a gem index
gem install builder --no-ri --no-rdoc

# place all gems into the server normally
[ ! -d gems ] && mkdir gems
[ -n "$(echo *.gem)" ] && mv *.gem gems

# compile gems for specific Ruby versions
[ ! -d ${RUBY19_ver}/gems ] && mkdir -p ${RUBY19_ver}/gems
[ ! -d ${RUBY18_ver}/gems ] && mkdir -p ${RUBY18_ver}/gems

# copy & compile gems which need compilation
for g in zookeeper-1.4.7; do
  [ -f "${RUBY18_ver}/gems/${g}.gem" ] && [ -f "${RUBY19_ver}/gems/${g}.gem" ] && continue
  export RUBYLIB=`pwd`/${RUBY18_ver}_gem_compile/lib
  pushd ${RUBY18_ver}/gems
  cp ../../gems/${g}.gem .
  ../../${RUBY18_ver}_gem_compile/bin/$GEM18 compile ${g}.gem
  popd
  export RUBYLIB=`pwd`/${RUBY19_ver}_gem_compile/lib
  pushd ${RUBY19_ver}/gems
  cp ../../gems/${g}.gem .
  ../../${RUBY19_ver}_gem_compile/bin/$GEM19 compile ${g}.gem
  popd
  unset RUBYLIB
done

gem generate_index --legacy
( pushd ${RUBY18_ver} &&
  RUBYLIB=`pwd`/../${RUBY18_ver}_gem_compile/lib ../${RUBY18_ver}_gem_compile/bin/$GEM18 install builder --no-ri --no-rdoc &&
  RUBYLIB=`pwd`/../${RUBY18_ver}_gem_compile/lib ../${RUBY18_ver}_gem_compile/bin/$GEM18 generate_index --legacy &&
  popd
)
( pushd ${RUBY19_ver} &&
  RUBYLIB=`pwd`/../${RUBY19_ver}_gem_compile/lib ../${RUBY19_ver}_gem_compile/bin/$GEM19 install builder --no-ri --no-rdoc &&
  RUBYLIB=`pwd`/../${RUBY19_ver}_gem_compile/lib ../${RUBY19_ver}_gem_compile/bin/$GEM19 generate_index --legacy &&
  popd
)

popd
