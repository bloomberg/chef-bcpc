#!/bin/bash -e
set -e

# This script must be invoked from the root of the repository (e.g., as
# bootstrap/shared/shared_build_bins.sh). It expects to run INSIDE the
# bootstrap VM, so it does not have access to environment variables or bootstrap
# functions. This script is invoked by shared/shared_configure_chef.sh.

# FILECACHE_MOUNT_POINT is exported in shared/shared_configure_chef.sh when invoking
# this script.
if [[ -z $FILECACHE_MOUNT_POINT ]]; then
  echo "FILECACHE_MOUNT_POINT must be set to proceed! Exiting." >&2
  exit 1
fi
if [[ -z $BUILD_DEST ]]; then BUILD_DEST=cookbooks/bcpc-binary-files/files/default; fi

# directory used for storing build cache products
BUILD_CACHE_DIR=$FILECACHE_MOUNT_POINT/build_bins_cache

# Binary versions to grab/build
source bootstrap/config/build_bins_versions.sh

pushd $BUILD_DEST

# copy existing build products out of the cache if dir exists
# (will not exist if this is the first time run with the new script)
if [ -d $BUILD_CACHE_DIR ]; then
  echo "Copying cached build products..."
  rsync -avxSH $BUILD_CACHE_DIR/* $(pwd -P)
fi

# Install tools needed for packaging
apt-get -y install git ruby-dev make pbuilder python-mock python-configobj python-support cdbs python-all-dev python-stdeb libmysqlclient-dev libldap2-dev libxml2-dev libxslt1-dev libpq-dev build-essential libssl-dev libffi-dev python-dev python-pip

# install fpm and support gems
if [ -z `gem list --local fpm | grep fpm | cut -f1 -d" "` ]; then
  pushd $FILECACHE_MOUNT_POINT/fpm_gems/
  gem install -l --no-ri --no-rdoc arr-pm-0.0.10.gem backports-3.6.4.gem cabin-0.7.1.gem childprocess-0.5.6.gem clamp-0.6.5.gem ffi-1.9.8.gem fpm-1.3.3.gem json-1.8.2.gem
  popd
fi

# Delete old kibana 4 deb
if [ -f kibana_${VER_KIBANA}_amd64.deb ]; then
  rm -f kibana_${VER_KIBANA}_amd64.deb kibana_${VER_KIBANA}.tar.gz
fi

# fluentd plugins and dependencies are fetched by shared_prereqs.sh, just copy them
# in from the local cache and add them to $FILES
rsync -avxSH $FILECACHE_MOUNT_POINT/fluentd_gems/* $(pwd -P)
FILES="$(ls -1 $FILECACHE_MOUNT_POINT/fluentd_gems/*.gem | xargs) $FILES"

# Fetch the cirros image for testing
if [ ! -f cirros-0.3.4-x86_64-disk.img ]; then
  cp -v $FILECACHE_MOUNT_POINT/cirros-0.3.4-x86_64-disk.img .
fi
FILES="cirros-0.3.4-x86_64-disk.img $FILES"

# Grab the Ubuntu 14.04 installer image
if [ ! -f ubuntu-14.04-mini.iso ]; then
  cp -v $FILECACHE_MOUNT_POINT/ubuntu-14.04-mini.iso ubuntu-14.04-mini.iso
fi
FILES="ubuntu-14.04-mini.iso $FILES"

# Test if diamond package version is <= 3.x, which implies a BrightCoveOS source
if [ -f diamond.deb ]; then
    if [ `dpkg-deb -f diamond.deb Version | cut -b1` -le 3 ]; then
        rm -f diamond.deb
    fi
fi
# Make the diamond package
if [ ! -f diamond.deb ]; then
  git clone $FILECACHE_MOUNT_POINT/python-diamond Diamond
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
  cp -r $FILECACHE_MOUNT_POINT/elasticsearch-head .
  cd elasticsearch-head
  git archive --output ../elasticsearch-plugins.tgz --prefix head/_site/ $VER_ESPLUGIN
  cd ..
  rm -rf elasticsearch-head
fi
FILES="elasticsearch-plugins.tgz $FILES"

# Fetch pyrabbit
if [ ! -f pyrabbit-1.0.1.tar.gz ]; then
  cp -v $FILECACHE_MOUNT_POINT/pyrabbit-1.0.1.tar.gz .
fi
FILES="pyrabbit-1.0.1.tar.gz $FILES"

# Build requests-aws package
if [ ! -f python-requests-aws_${VER_REQUESTS_AWS}_all.deb ]; then
  cp -v $FILECACHE_MOUNT_POINT/requests-aws-${VER_REQUESTS_AWS}.tar.gz .
  tar zxf requests-aws-${VER_REQUESTS_AWS}.tar.gz
  fpm -s python -t deb -f requests-aws-${VER_REQUESTS_AWS}/setup.py
  rm -rf requests-aws-${VER_REQUESTS_AWS}.tar.gz requests-aws-${VER_REQUESTS_AWS}
fi
FILES="python-requests-aws_${VER_REQUESTS_AWS}_all.deb $FILES"

# Build pyzabbix package
if [ ! -f python-pyzabbix_${VER_PYZABBIX}_all.deb ]; then
  cp -v $FILECACHE_MOUNT_POINT/pyzabbix-${VER_PYZABBIX}.tar.gz .
  tar zxf pyzabbix-${VER_PYZABBIX}.tar.gz
  fpm -s python -t deb -f pyzabbix-${VER_PYZABBIX}/setup.py
  rm -rf pyzabbix-${VER_PYZABBIX}.tar.gz pyzabbix-${VER_PYZABBIX}
fi
FILES="python-pyzabbix_${VER_PYZABBIX}_all.deb $FILES"

# Grab Zabbix-Pagerduty notification script
if [ ! -f pagerduty-zabbix-proxy.py ]; then
  cp -v $FILECACHE_MOUNT_POINT/pagerduty-zabbix-proxy.py .
fi
FILES="pagerduty-zabbix-proxy.py $FILES"

# Build graphite packages
if [ ! -f python-carbon_${VER_GRAPHITE_CARBON}_all.deb ]; then
  cp -v $FILECACHE_MOUNT_POINT/carbon-${VER_GRAPHITE_CARBON}.tar.gz .
  tar zxf carbon-${VER_GRAPHITE_CARBON}.tar.gz
  fpm --python-install-bin /opt/graphite/bin -s python -t deb -f carbon-${VER_GRAPHITE_CARBON}/setup.py
  rm -rf carbon-${VER_GRAPHITE_CARBON} carbon-${VER_GRAPHITE_CARBON}.tar.gz
fi
FILES="python-carbon_${VER_GRAPHITE_CARBON}_all.deb $FILES"

if [ ! -f python-whisper_${VER_GRAPHITE_WHISPER}_all.deb ]; then
  cp -v $FILECACHE_MOUNT_POINT/whisper-${VER_GRAPHITE_WHISPER}.tar.gz .
  tar zxf whisper-${VER_GRAPHITE_WHISPER}.tar.gz
  fpm --python-install-bin /opt/graphite/bin -s python -t deb -f whisper-${VER_GRAPHITE_WHISPER}/setup.py
  rm -rf whisper-${VER_GRAPHITE_WHISPER} whisper-${VER_GRAPHITE_WHISPER}.tar.gz
fi
FILES="python-whisper_${VER_GRAPHITE_WHISPER}_all.deb $FILES"

if [ ! -f python-graphite-web_${VER_GRAPHITE_WEB}_all.deb ]; then
  cp -v $FILECACHE_MOUNT_POINT/graphite-web-${VER_GRAPHITE_WEB}.tar.gz .
  tar zxf graphite-web-${VER_GRAPHITE_WEB}.tar.gz
  fpm --python-install-lib /opt/graphite/webapp -s python -t deb -f graphite-web-${VER_GRAPHITE_WEB}/setup.py
  rm -rf graphite-web-${VER_GRAPHITE_WEB} graphite-web-${VER_GRAPHITE_WEB}.tar.gz
fi
FILES="python-graphite-web_${VER_GRAPHITE_WEB}_all.deb $FILES"

###### Install golang
export PATH=$PATH:/usr/local/go/bin
if [ `go version 2>/dev/null | grep -c $VER_GOLANG` != 1 ]; then
  test -d /usr/local/go && rm -rf /usr/local/go
  tar zxf $FILECACHE_MOUNT_POINT/go${VER_GOLANG}.linux-amd64.tar.gz -C /usr/local
fi
# Create Go workspace
export GOPATH=$FILECACHE_MOUNT_POINT/go
for dir in src bin pkg; do
  if [ ! -d $GOPATH/$dir ]; then
    mkdir -p $GOPATH/$dir
  fi
done
###### golang install ends

# Build Prometheus Graphite exporter
if [ ! -f graphite_exporter ]; then
  if [ ! -d $GOPATH/src/github.com/prometheus ]; then
    mkdir -p $GOPATH/src/github.com/prometheus
  fi
  GRAPHITE_EXPORTER_SRC=$GOPATH/src/github.com/prometheus/graphite_exporter
  git clone $FILECACHE_MOUNT_POINT/graphite_exporter $GRAPHITE_EXPORTER_SRC
  git -C $GRAPHITE_EXPORTER_SRC checkout $VER_GRAPHITE_EXPORTER
  make -C $GRAPHITE_EXPORTER_SRC
  cp -v $GRAPHITE_EXPORTER_SRC/graphite_exporter .
  rm -rf $GRAPHITE_EXPORTER_SRC
fi

# Rally has a number of dependencies. Some of the dependencies are in apt by default but some are not. Those that
# are not are built here.

# We build a package for rally here but we also get the tar file of the source because it includes the samples
# directory that we want and we need a good place to run our tests from.

if [ ! -f rally.tar.gz ]; then
  cp $FILECACHE_MOUNT_POINT/rally/rally-${VER_RALLY}.tar.gz .
  tar xvf rally-${VER_RALLY}.tar.gz
  tar zcf rally.tar.gz -C rally-${VER_RALLY}/ .
  rm -rf rally-${VER_RALLY}.tar.gz rally-${VER_RALLY}
fi

# TODO FOR erhudy: fix up these Rally packages to be built like the Graphite stuff

# Also test for deb if migrating from 5.1.x
if [ ! -f rally-pip.tar.gz ] || [ ! -f rally-bin.tar.gz ] || [ ! -f python-pip_${VER_PIP}_all.deb ]; then
  # Rally has a very large number of version specific dependencies!!
  # The latest version of PIP is installed instead of the distro version. We don't want this to block to exit on error
  # so it is changed here and reset at the end. Several apt packages must be present since easy_install builds
  # some of the dependencies.
  # Note: Once we fully switch to trusty/kilo then we should not have to patch this (hopefully).
  echo "Processing Rally setup..."

  # Create a deb for pip to replace really old upstream pip
  if [[ ! -f python-pip_${VER_PIP}_all.deb ]]; then
    cp $FILECACHE_MOUNT_POINT/rally/pip-${VER_PIP}.tar.gz .
    tar xvzf pip-${VER_PIP}.tar.gz
    fpm -s python -t deb pip-${VER_PIP}/setup.py
    dpkg -i python-pip_${VER_PIP}_all.deb
    rm -rf pip-${VER_PIP} pip-${VER_PIP}.tar.gz
  fi

  # We install rally and a few other items here. Since fpm does not resolve dependencies but only lists them, we
  # have to force an install and then tar up the dist-packages and local/bin
  PIP_INSTALL="pip install --no-cache-dir --disable-pip-version-check --no-index -f $FILECACHE_MOUNT_POINT/rally"
  # this kludge is to prevent easy_install from trying to go out to PyPI:
  # rally calls setuptools.setup_requires(), which uses easy_install to
  # install any packages listed there; this forces easy_install to use
  # the same mechanism as we are telling pip to use in $PIP_INSTALL
  echo -e "[easy_install]\nallow_hosts = ''\nfind_links = file://$FILECACHE_MOUNT_POINT/rally/" > $HOME/.pydistutils.cfg
  $PIP_INSTALL --default-timeout 60 -I rally
  $PIP_INSTALL --default-timeout 60 python-openstackclient
  $PIP_INSTALL -U argparse
  $PIP_INSTALL -U setuptools

  tar zcf rally-pip.tar.gz -C /usr/local/lib/python2.7/dist-packages .
  tar zcf rally-bin.tar.gz --exclude="fpm" --exclude="ruby*" -C /usr/local/bin .
fi
FILES="rally.tar.gz rally-pip.tar.gz rally-bin.tar.gz python-pip_${VER_PIP}_all.deb $FILES"
# End of Rally

# rsync build products with cache directory
mkdir -p $BUILD_CACHE_DIR && rsync -avxSH $(pwd -P)/* $BUILD_CACHE_DIR

popd # $BUILD_DEST
