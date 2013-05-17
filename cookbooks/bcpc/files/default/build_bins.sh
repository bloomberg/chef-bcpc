#!/bin/bash -e

set -x

DIR=`dirname $0`

pushd $DIR/bins/

# Get up to date
apt-get -y update
apt-get -y dist-upgrade

# Install tools needed for packaging
apt-get -y install git rubygems make pbuilder python-mock python-configobj python-support cdbs python-all-dev python-stdeb libmysqlclient-dev
if [ -z `gem list --local bundler | grep bundler | cut -f1 -d" "` ]; then
  gem install bundler --no-ri --no-rdoc
fi
if [ -z `gem list --local fpm | grep fpm | cut -f1 -d" "` ]; then
  gem install fpm --no-ri --no-rdoc
fi

# Build kibana installable bundle
if [ ! -f kibana.tgz ]; then
    git clone https://github.com/rashidkpc/Kibana.git kibana
    cd kibana
    bundle install --standalone
    cd ..
    tar czf kibana.tgz kibana
    rm -rf kibana
fi
FILES="kibana.tgz $FILES"

# Fetch the cirros image for testing
if [ ! -f cirros-0.3.0-x86_64-disk.img ]; then
    curl -O -L https://launchpad.net/cirros/trunk/0.3.0/+download/cirros-0.3.0-x86_64-disk.img
fi
FILES="cirros-0.3.0-x86_64-disk.img $FILES"

# Grab the Ubuntu 12.04 installer image
if [ ! -f ubuntu-12.04-mini.iso ]; then
    curl -o ubuntu-12.04-mini.iso http://archive.ubuntu.com/ubuntu/dists/precise/main/installer-amd64/current/images/netboot/mini.iso
fi
FILES="ubuntu-12.04-mini.iso $FILES"

# Make the diamond package
if [ ! -f diamond.deb ]; then
    git clone https://github.com/BrightcoveOS/Diamond.git
    cd Diamond
    make builddeb
    VERSION=`cat version.txt`
    cd ..
    mv Diamond/build/diamond_${VERSION}_all.deb diamond.deb
    rm -rf Diamond
fi
FILES="diamond.deb $FILES"

# Snag elasticsearch
if [ ! -f elasticsearch-0.20.2.deb ]; then
    curl -O -L https://download.elasticsearch.org/elasticsearch/elasticsearch/elasticsearch-0.20.2.deb
fi
FILES="elasticsearch-0.20.2.deb $FILES"

if [ ! -f elasticsearch-plugins.tgz ]; then
    mkdir head
    cd head
    git clone https://github.com/mobz/elasticsearch-head.git _site
    cd ..
    tar czf elasticsearch-plugins.tgz head
    rm -rf head
fi
FILES="elasticsearch-plugins.tgz $FILES"


# Snag logstash
if [ ! -f logstash-1.1.9-monolithic.jar ]; then
    curl -O -L https://logstash.objects.dreamhost.com/release/logstash-1.1.9-monolithic.jar
fi
FILES="logstash-1.1.9-monolithic.jar $FILES"

# Fetch pyrabbit
if [ ! -f pyrabbit-1.0.1.tar.gz ]; then
    curl -O -L https://pypi.python.org/packages/source/p/pyrabbit/pyrabbit-1.0.1.tar.gz
fi
FILES="pyrabbit-1.0.1.tar.gz $FILES"

# Build python ujson
if [ ! -f python-ujson_1.30-1_amd64.deb ]; then
    curl -L -O https://pypi.python.org/packages/source/u/ujson/ujson-1.30.zip
    unzip ujson-1.30.zip
    cd ujson-1.30
    python setup.py --command-packages=stdeb.command bdist_deb
    cd ..
    cp ujson-1.30/deb_dist/python-ujson_1.30-1_amd64.deb .
    rm -rf ujson-1.30 ujson-1.30.zip
fi
FILES="python-ujson_1.30-1_amd64.deb $FILES"

# Build python glob2
if [ ! -f python-glob2_0.3-1_all.deb ]; then
    curl -L -O https://pypi.python.org/packages/source/g/glob2/glob2-0.3.tar.gz
    tar zxf glob2-0.3.tar.gz
    cd glob2-0.3
    python setup.py --command-packages=stdeb.command bdist_deb
    cd ..
    cp glob2-0.3/deb_dist/python-glob2_0.3-1_all.deb .
    rm -rf glob2-0.3 glob2-0.3.tar.gz
fi
FILES="python-glob2_0.3-1_all.deb $FILES"

# Build beaver package
if [ ! -f python-beaver_28-1_all.deb ]; then
    curl -L -O https://pypi.python.org/packages/source/B/Beaver/Beaver-28.tar.gz
    tar zxf Beaver-28.tar.gz
    cd Beaver-28
    python setup.py --command-packages=stdeb.command bdist_deb
    cd ..
    cp Beaver-28/deb_dist/python-beaver_28-1_all.deb .
    rm -rf Beaver-28 Beaver-28.tar.gz
fi
FILES="python-beaver_28-1_all.deb $FILES"

# Build graphite packages
if [ ! -f python-carbon_0.9.10_all.deb ] || [ ! -f python-whisper_0.9.10_all.deb ] || [ ! -f python-graphite-web_0.9.10_all.deb ]; then
    curl -L -O http://pypi.python.org/packages/source/c/carbon/carbon-0.9.10.tar.gz
    curl -L -O http://pypi.python.org/packages/source/w/whisper/whisper-0.9.10.tar.gz
    curl -L -O http://pypi.python.org/packages/source/g/graphite-web/graphite-web-0.9.10.tar.gz
    tar zxf carbon-0.9.10.tar.gz
    tar zxf whisper-0.9.10.tar.gz
    tar zxf graphite-web-0.9.10.tar.gz
    fpm --python-install-bin /opt/graphite/bin -s python -t deb carbon-0.9.10/setup.py
    fpm --python-install-bin /opt/graphite/bin  -s python -t deb whisper-0.9.10/setup.py
    fpm --python-install-lib /opt/graphite/webapp -s python -t deb graphite-web-0.9.10/setup.py
    rm -rf carbon-0.9.10 carbon-0.9.10.tar.gz whisper-0.9.10 whisper-0.9.10.tar.gz graphite-web-0.9.10 graphite-web-0.9.10.tar.gz
fi
FILES="python-carbon_0.9.10_all.deb python-whisper_0.9.10_all.deb python-graphite-web_0.9.10_all.deb $FILES"

# Build the zabbix packages
if [ ! -f zabbix-agent.tar.gz ] || [ ! -f zabbix-server.tar.gz ]; then
    curl -L -O http://sourceforge.net/projects/zabbix/files/ZABBIX%20Latest%20Stable/2.0.6/zabbix-2.0.6.tar.gz
    tar zxf zabbix-2.0.6.tar.gz
    rm -rf /tmp/zabbix-install && mkdir -p /tmp/zabbix-install
    cd zabbix-2.0.6
    ./configure --prefix=/tmp/zabbix-install --enable-agent
    make install
    tar zcf zabbix-agent.tar.gz -C /tmp/zabbix-install .
    rm -rf /tmp/zabbix-install && mkdir -p /tmp/zabbix-install
    ./configure --prefix=/tmp/zabbix-install --enable-server --with-mysql
    make install
    cp -a frontends/php /tmp/zabbix-install/share/zabbix/
    cp database/mysql/* /tmp/zabbix-install/share/zabbix/
    tar zcf zabbix-server.tar.gz -C /tmp/zabbix-install .
    rm -rf /tmp/zabbix-install
    cd ..
    cp zabbix-2.0.6/zabbix-agent.tar.gz .
    cp zabbix-2.0.6/zabbix-server.tar.gz .
    rm -rf zabbix-2.0.6 zabbix-2.0.6.tar.gz
fi
FILES="zabbix-agent.tar.gz zabbix-server.tar.gz $FILES"

popd
