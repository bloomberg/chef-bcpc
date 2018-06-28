#!/bin/bash -e
set -ex

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
BUILD_CACHE_DIR="$FILECACHE_MOUNT_POINT/build_bins_cache"

# Binary versions to grab/build
source bootstrap/config/build_bins_versions.sh

pushd $BUILD_DEST

# copy existing build products out of the cache if dir exists
# (will not exist if this is the first time run with the new script)
if [[ -d "$BUILD_CACHE_DIR" ]]; then
  echo "Copying cached build products..."
  rsync -avxSH "$BUILD_CACHE_DIR"/* "$(pwd -P)"
fi

# Install tools needed for packaging
apt-get -y install git ruby-dev make pbuilder python-mock python-configobj python-support cdbs python-all-dev python-stdeb libmysqlclient-dev libldap2-dev libxml2-dev libxslt1-dev libpq-dev build-essential libssl-dev libffi-dev python-dev python-pip jq

# install fpm and support gems
if [[ -z "$(gem list --local fpm | awk '/fpm/ {print $1}')" ]]; then
  pushd "$FILECACHE_MOUNT_POINT/fpm_gems/"
  gem install -l --no-ri --no-rdoc arr-pm-0.0.10.gem backports-3.6.4.gem cabin-0.7.1.gem childprocess-0.5.6.gem clamp-0.6.5.gem ffi-1.9.8.gem fpm-1.3.3.gem json-1.8.2.gem
  popd
fi

# Delete old kibana 4 deb
if [[ -f kibana_"${VER_KIBANA}"_amd64.deb ]]; then
  rm -f kibana_"${VER_KIBANA}"_amd64.deb kibana_"${VER_KIBANA}".tar.gz
fi

# fluentd plugins and dependencies are fetched by shared_prereqs.sh, just copy them
# in from the local cache and add them to $FILES
rsync -avxSH "${FILECACHE_MOUNT_POINT}"/fluentd_gems/* "$(pwd -P)"
FILES+=$(ls -1 "${FILECACHE_MOUNT_POINT}"/fluentd_gems/*.gem)

# Fetch the cirros image for testing
if [[ ! -f cirros-0.3.4-x86_64-disk.img ]]; then
  cp -v "$FILECACHE_MOUNT_POINT/cirros-0.3.4-x86_64-disk.img" .
fi
FILES+="cirros-0.3.4-x86_64-disk.img $FILES"

# Grab the Ubuntu 14.04 installer image
if [[ ! -f ubuntu-14.04-mini.iso ]]; then
  cp -v "${FILECACHE_MOUNT_POINT}"/ubuntu-14.04-mini.iso ubuntu-14.04-mini.iso
fi
FILES="ubuntu-14.04-mini.iso $FILES"

# Test if diamond package version is <= 3.x, which implies a BrightCoveOS source
if [[ -f diamond.deb ]]; then
    if [[ "$(dpkg-deb -f diamond.deb Version | cut -b1)" -le 3 ]]; then
        rm -f diamond.deb
    fi
fi
# Make the diamond package
if [[ ! -f diamond.deb ]]; then
  git clone "$FILECACHE_MOUNT_POINT/python-diamond" Diamond &&
  cd Diamond &&
  git checkout "$VER_DIAMOND" &&
  make builddeb &&
  diamond_version=$(< version.txt) &&
  cd .. &&
  mv Diamond/build/diamond_"${diamond_version}"_all.deb diamond.deb &&
  rm -rf Diamond || exit
fi
FILES="diamond.deb $FILES"

if [[ ! -f elasticsearch-plugins.tgz ]]; then
  cp -r "$FILECACHE_MOUNT_POINT/elasticsearch-head" . &&
  cd elasticsearch-head &&
  git archive --output ../elasticsearch-plugins.tgz --prefix head/_site/ "$VER_ESPLUGIN" &&
  cd .. &&
  rm -rf elasticsearch-head || exit
fi
FILES="elasticsearch-plugins.tgz $FILES"

# Fetch pyrabbit
if [[ ! -f pyrabbit-1.0.1.tar.gz ]]; then
  cp -v "${FILECACHE_MOUNT_POINT}"/pyrabbit-1.0.1.tar.gz .
fi
FILES="pyrabbit-1.0.1.tar.gz $FILES"

# Build requests-aws package
if [[ ! -f python-requests-aws_"${VER_REQUESTS_AWS}"_all.deb ]]; then
  tar zxf "${FILECACHE_MOUNT_POINT}"/requests-aws-"${VER_REQUESTS_AWS}".tar.gz -C . &&
  fpm -s python -t deb -f requests-aws-"${VER_REQUESTS_AWS}"/setup.py || exit
fi
FILES="python-requests-aws_${VER_REQUESTS_AWS}_all.deb $FILES"

# Build pyzabbix package
if [[ ! -f python-pyzabbix_"${VER_PYZABBIX}"_all.deb ]]; then
  tar zxf "${FILECACHE_MOUNT_POINT}"/pyzabbix-"${VER_PYZABBIX}".tar.gz -C . &&
  fpm -s python -t deb -f pyzabbix-"${VER_PYZABBIX}"/setup.py || exit
fi
FILES="python-pyzabbix_${VER_PYZABBIX}_all.deb $FILES"

# Grab Zabbix-Pagerduty notification script
if [[ ! -f pagerduty-zabbix-proxy.py ]]; then
  cp -v "$FILECACHE_MOUNT_POINT/pagerduty-zabbix-proxy.py" .
fi
FILES="pagerduty-zabbix-proxy.py $FILES"

# Build graphite packages
if [[ ! -f python-carbon_"${VER_GRAPHITE_CARBON}"_all.deb ]]; then
  tar zxf "${FILECACHE_MOUNT_POINT}"/carbon-"${VER_GRAPHITE_CARBON}".tar.gz -C . &&
  fpm --python-install-bin /opt/graphite/bin -s python -t deb -f carbon-"${VER_GRAPHITE_CARBON}"/setup.py || exit
fi
FILES="python-carbon_${VER_GRAPHITE_CARBON}_all.deb $FILES"

if [[ ! -f python-whisper_"${VER_GRAPHITE_WHISPER}"_all.deb ]]; then
  tar zxf "${FILECACHE_MOUNT_POINT}"/whisper-"${VER_GRAPHITE_WHISPER}".tar.gz -C . &&
  fpm --python-install-bin /opt/graphite/bin -s python -t deb -f whisper-"${VER_GRAPHITE_WHISPER}"/setup.py || exit
fi
FILES="python-whisper_${VER_GRAPHITE_WHISPER}_all.deb $FILES"

if [[ ! -f "python-graphite-web_${VER_GRAPHITE_WEB}_all.deb" ]]; then
  tar zxf "${FILECACHE_MOUNT_POINT}"/graphite-web-"${VER_GRAPHITE_WEB}".tar.gz -C . &&
  fpm --python-install-lib /opt/graphite/webapp -s python -t deb -f graphite-web-"${VER_GRAPHITE_WEB}"/setup.py || exit
fi
FILES="python-graphite-web_${VER_GRAPHITE_WEB}_all.deb $FILES"

# add calicoctl binary
CALICOCTL_BINARY=calicoctl-"${VER_CALICOCTL}"
if [[ ! -f "$CALICOCTL_BINARY" ]]; then
  cp -v "$FILECACHE_MOUNT_POINT/$CALICOCTL_BINARY" .
fi
FILES="$CALICOCTL_BINARY $FILES"

# rsync build products with cache directory
mkdir -p "$BUILD_CACHE_DIR" && rsync -avxSH "$(pwd -P)"/* "$BUILD_CACHE_DIR"

popd # $BUILD_DEST
