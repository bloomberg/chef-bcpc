#!/bin/bash
# Exit immediately if anything goes wrong, instead of making things worse.
set -e
####################################################################

# NB(kamidzi): following calls load_configs(); potentially is destructive to settings
if [[ ! -z "$BOOTSTRAP_HTTP_PROXY_URL" ]] || [[ ! -z "$BOOTSTRAP_HTTPS_PROXY_URL" ]] ; then
  echo "Testing configured proxies..."
  source "$REPO_ROOT/bootstrap/shared/shared_proxy_setup.sh"
else
  source "$REPO_ROOT/bootstrap/shared/shared_functions.sh"
fi

REQUIRED_VARS=( BOOTSTRAP_CACHE_DIR REPO_ROOT )
check_for_envvars "${REQUIRED_VARS[@]}"

# Create directory for download cache.
mkdir -p "$BOOTSTRAP_CACHE_DIR"

ubuntu_url="http://us.archive.ubuntu.com/ubuntu/dists/trusty-updates"

chef_url="https://packages.chef.io/files/stable"
chef_client_ver=12.9.41
chef_server_ver=12.6.0
CHEF_CLIENT_DEB=${CHEF_CLIENT_DEB:-chef_${chef_client_ver}-1_amd64.deb}
CHEF_SERVER_DEB=${CHEF_SERVER_DEB:-chef-server-core_${chef_server_ver}-1_amd64.deb}

cirros_url="http://download.cirros-cloud.net"
cirros_version="0.3.4"

cloud_img_url="https://cloud-images.ubuntu.com/vagrant/trusty/current"
# cloud_img_url="https://mirrors.tuna.tsinghua.edu.cn/ubuntu-cloud-images/vagrant/trusty/current"

cloud_img_box="trusty-server-cloudimg-amd64-vagrant-disk1.box"
netboot_iso="ubuntu-14.04-mini.iso"
pypi_url="https://pypi.python.org/packages/source"
pxe_rom="gpxe-1.0.1-80861004.rom"
ruby_gem_url="https://rubygems.global.ssl.fastly.net/gems"

vbox_version="5.0.36"
vbox_additions="VBoxGuestAdditions_$vbox_version.iso"
vbox_url="http://download.virtualbox.org/virtualbox"

# List of binary versions to download
source "$REPO_ROOT/bootstrap/config/build_bins_versions.sh"

curl_cmd() { curl -f --progress -L -H 'Accept-encoding: gzip,deflate' "$@"; }

####################################################################
# download_file wraps the usual behavior of curling a remote URL to a local file
download_file() {
  input_file="$1"
  remote_url="$2"

  if [[ ! -f "$BOOTSTRAP_CACHE_DIR/$input_file" && ! -f "$BOOTSTRAP_CACHE_DIR/${input_file}_downloaded" ]]; then
    trap 'echo && echo Download interrupted, cleaning up partial download of "$BOOTSTRAP_CACHE_DIR"/"$input_file" && rm -f "$BOOTSTRAP_CACHE_DIR"/"$input_file"' INT
    echo "Downloading $input_file..."
    curl_cmd -o "$BOOTSTRAP_CACHE_DIR/$input_file" "$remote_url" -Sw '[%{http_code}]\n'
    if [[ $? != 0 ]]; then
      echo "Received error when attempting to download from ${remote_url}."
    fi

  fi
}

####################################################################
# cleanup_cookbook removes all but the specified cookbook version so that we
# don't keep old cookbook versions and clobber them when decompressing
cleanup_cookbook() {
  COOKBOOK="$1"
  VERSION_TO_KEEP="$2"

  # this syntax should work with both BSD and GNU find (for building on OS X and Linux)
  find "${BOOTSTRAP_CACHE_DIR}/cookbooks/" -name "${COOKBOOK}-\*.tar.gz" -and -not -name "${COOKBOOK}-${VERSION_TO_KEEP}.tar.gz" -delete && true
  find "${BOOTSTRAP_CACHE_DIR}/cookbooks/" -name "${COOKBOOK}-\*.tar.gz_downloaded" -and -not -name "${COOKBOOK}-${VERSION_TO_KEEP}.tar.gz_downloaded" -delete && true
}

####################################################################
# download_cookbook wraps download_file for retrieving cookbooks
download_cookbook() {
  COOKBOOK="$1"
  VERSION_TO_GET="$2"

  download_file "cookbooks/${COOKBOOK}-${VERSION_TO_GET}.tar.gz" "http://cookbooks.opscode.com/api/v1/cookbooks/${COOKBOOK}/versions/${VERSION_TO_GET}/download"
}

####################################################################
# cleanup_and_download_cookbook wraps both cleanup_cookbook and download_cookbook
cleanup_and_download_cookbook() {
  COOKBOOK="$1"
  TARGET_VERSION="$2"

  cleanup_cookbook "${COOKBOOK}" "${TARGET_VERSION}"
  download_cookbook "${COOKBOOK}" "${TARGET_VERSION}"
}

####################################################################
# Clones a repo and attempts to pull updates if requested version does not exist
clone_repo() {
  repo_url="$1"
  local_dir="$2"
  version="$3"

  if [[ -d "$BOOTSTRAP_CACHE_DIR/$local_dir/.git" ]]; then
    pushd "$BOOTSTRAP_CACHE_DIR/$local_dir"
    git log --pretty=format:'%H' | \
    grep -q "$version" || \
    git pull
    popd
  else
    git clone "$repo_url" "$BOOTSTRAP_CACHE_DIR/$local_dir"
  fi
}

####################################################################
# This uses ROM-o-Matic to generate a custom PXE boot ROM.
# (doesn't use the function because of the unique curl command)
if [[ -f "$BOOTSTRAP_CACHE_DIR/$pxe_rom" && ! -f "$BOOTSTRAP_CACHE_DIR/${pxe_rom}_downloaded" ]]; then
  rm -f "$BOOTSTRAP_CACHE_DIR/$pxe_rom"
fi
if [[ ! -f "$BOOTSTRAP_CACHE_DIR/$pxe_rom" && ! -f "$BOOTSTRAP_CACHE_DIR/${pxe_rom}_downloaded" ]]; then
  echo "$pxe_rom"
  rm -f "$BOOTSTRAP_CACHE_DIR/$pxe_rom"
  curl -L --progress-bar -H 'Accept-Encoding: gzip,deflate' -o "$BOOTSTRAP_CACHE_DIR/$pxe_rom" "http://rom-o-matic.eu/gpxe/gpxe-1.0.1/contrib/rom-o-matic/build.php" -H "Origin: http://rom-o-matic.eu" -H "Host: rom-o-matic.eu" -H "Content-Type: application/x-www-form-urlencoded" -H "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8" -H "Referer: http://rom-o-matic.eu/gpxe/gpxe-1.0.1/contrib/rom-o-matic/build.php" -H "Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.3" --data "version=1.0.1&use_flags=1&ofmt=ROM+binary+%28flashable%29+image+%28.rom%29&nic=all-drivers&pci_vendor_code=8086&pci_device_code=1004&PRODUCT_NAME=&PRODUCT_SHORT_NAME=gPXE&CONSOLE_PCBIOS=on&BANNER_TIMEOUT=20&NET_PROTO_IPV4=on&COMCONSOLE=0x3F8&COMSPEED=115200&COMDATA=8&COMPARITY=0&COMSTOP=1&DOWNLOAD_PROTO_TFTP=on&DNS_RESOLVER=on&NMB_RESOLVER=off&IMAGE_ELF=on&IMAGE_NBI=on&IMAGE_MULTIBOOT=on&IMAGE_PXE=on&IMAGE_SCRIPT=on&IMAGE_BZIMAGE=on&IMAGE_COMBOOT=on&AUTOBOOT_CMD=on&NVO_CMD=on&CONFIG_CMD=on&IFMGMT_CMD=on&IWMGMT_CMD=on&ROUTE_CMD=on&IMAGE_CMD=on&DHCP_CMD=on&SANBOOT_CMD=on&LOGIN_CMD=on&embedded_script=&A=Get+Image"
  touch "$BOOTSTRAP_CACHE_DIR/${pxe_rom}_downloaded"
fi

####################################################################
# Obtain an Ubuntu netboot image to be used for PXE booting.
download_file "$netboot_iso" "$ubuntu_url/main/installer-amd64/current/images/netboot/mini.iso"


####################################################################
# Obtain the VirtualBox guest additions ISO for use with Ansible.
download_file "$vbox_additions" "$vbox_url/$vbox_version/$vbox_additions"


####################################################################
# Obtain a Vagrant Trusty box.
download_file "$cloud_img_box" "$cloud_img_url/$cloud_img_box"


####################################################################
# Obtain Chef client and server DEBs.
download_file "$CHEF_CLIENT_DEB" "$chef_url/chef/$chef_client_ver/ubuntu/14.04/$CHEF_CLIENT_DEB"
download_file "$CHEF_SERVER_DEB" "$chef_url/chef-server-core/$chef_server_ver/ubuntu/14.04/$CHEF_SERVER_DEB"

####################################################################
# Pull needed cookbooks from the Chef Supermarket (and remove the previous
# versions if present). Versions are pulled from build_bins_versions.sh.
mkdir -p "$BOOTSTRAP_CACHE_DIR/cookbooks"
cleanup_and_download_cookbook apt "${VER_APT_COOKBOOK}"
cleanup_and_download_cookbook chef-client "${VER_CHEF_CLIENT_COOKBOOK}"
cleanup_and_download_cookbook chef_handler "${VER_CHEF_HANDLER_COOKBOOK}"
cleanup_and_download_cookbook concat "${VER_CONCAT_COOKBOOK}"
cleanup_and_download_cookbook cron "${VER_CRON_COOKBOOK}"
cleanup_and_download_cookbook hostsfile "${VER_HOSTSFILE_COOKBOOK}"
cleanup_and_download_cookbook logrotate "${VER_LOGROTATE_COOKBOOK}"
cleanup_and_download_cookbook ntp "${VER_NTP_COOKBOOK}"
cleanup_and_download_cookbook ubuntu "${VER_UBUNTU_COOKBOOK}"
cleanup_and_download_cookbook windows "${VER_WINDOWS_COOKBOOK}"
cleanup_and_download_cookbook yum "${VER_YUM_COOKBOOK}"


####################################################################
# Pull knife-acl gem.
download_file knife-acl-1.0.2.gem "$ruby_gem_url/knife-acl-1.0.2.gem"


####################################################################
# Pull needed gems for fpm.
declare -a ruby_fpm_gems

ruby_fpm_gems=(); while IFS= read -r; do 
	[[ $REPLY ]] && ruby_fpm_gems+=("$REPLY"); done < "$REPO_ROOT/bootstrap/shared/ruby_fpm.gems"

mkdir -p "$BOOTSTRAP_CACHE_DIR/fpm_gems"
for gem in "${ruby_fpm_gems[@]}"; do
	download_file "fpm_gems/$gem.gem" "$ruby_gem_url/$gem.gem"
done


####################################################################
# Pull needed gems for fluentd.
declare -a ruby_fluentd_gems

ruby_fluentd_gems=(); while IFS= read -r; do 
	[[ $REPLY ]] && ruby_fluentd_gems+=("$REPLY"); done < "$REPO_ROOT/bootstrap/shared/ruby_fluentd.gems"

mkdir -p "$BOOTSTRAP_CACHE_DIR/fluentd_gems"
for gem in "${ruby_fluentd_gems[@]}"; do
	download_file "fluentd_gems/$gem.gem" "$ruby_gem_url/$gem.gem"
done


####################################################################
# Obtain Cirros image.
download_file "cirros-$cirros_version-x86_64-disk.img" "$cirros_url/$cirros_version/cirros-$cirros_version-x86_64-disk.img"


####################################################################
# Obtain various items used for monitoring.
# Remove obsolete kibana package
rm -f "$BOOTSTRAP_CACHE_DIR/kibana-4.0.2-linux-x64.tar.gz_downloaded" "$BOOTSTRAP_CACHE_DIR/kibana-4.0.2-linux-x64.tar.gz"
# Remove obsolete cached items for BrightCoveOS Diamond
rm -rf "$BOOTSTRAP_CACHE_DIR/diamond_downloaded" "$BOOTSTRAP_CACHE_DIR/diamond"

clone_repo https://github.com/python-diamond/Diamond python-diamond "$VER_DIAMOND"
clone_repo https://github.com/mobz/elasticsearch-head elasticsearch-head "$VER_ESPLUGIN"

download_file pyrabbit-1.0.1.tar.gz $pypi_url/p/pyrabbit/pyrabbit-1.0.1.tar.gz
download_file requests-aws-0.1.6.tar.gz $pypi_url/r/requests-aws/requests-aws-0.1.6.tar.gz
download_file pyzabbix-0.7.3.tar.gz $pypi_url/p/pyzabbix/pyzabbix-0.7.3.tar.gz
download_file pagerduty-zabbix-proxy.py https://gist.githubusercontent.com/ryanhoskin/202a1497c97b0072a83a/raw/96e54cecdd78e7990bb2a6cc8f84070599bdaf06/pd-zabbix-proxy.py
download_file carbon-"${VER_GRAPHITE_CARBON}".tar.gz "$pypi_url/c/carbon/carbon-${VER_GRAPHITE_CARBON}.tar.gz"
download_file whisper-"${VER_GRAPHITE_WHISPER}".tar.gz "$pypi_url/w/whisper/whisper-${VER_GRAPHITE_WHISPER}.tar.gz"
download_file graphite-web-"${VER_GRAPHITE_WEB}".tar.gz "$pypi_url/g/graphite-web/graphite-web-${VER_GRAPHITE_WEB}.tar.gz"

####################################################################
# get calicoctl for Neutron+Calico experiments
download_file "calicoctl-${VER_CALICOCTL}" "https://github.com/projectcalico/calicoctl/releases/download/${VER_CALICOCTL}/calicoctl"
