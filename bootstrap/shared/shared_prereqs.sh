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
packages_json="$REPO_ROOT/bootstrap/config/packages.json"
pypi_url="https://pypi.python.org/packages/source"
pxe_rom="gpxe-1.0.1-80861004.rom"
cookbook_base="https://supermarket.chef.io/cookbooks"
ruby_gem_url="https://rubygems.global.ssl.fastly.net/gems"
vbox_version="5.0.36"
vbox_additions="VBoxGuestAdditions_$vbox_version.iso"
vbox_url="http://download.virtualbox.org/virtualbox"

# List of binary versions to download
source "$REPO_ROOT/bootstrap/config/build_bins_versions.sh"

curl_cmd() { curl -\# -L -4 -f -H 'Accept-encoding: gzip,deflate' "$@"; }

####################################################################
# download_file wraps the usual behavior of curling a remote URL to a local file
download_file() {
  input_file="$1"
  remote_url="$2"

  trap 'echo && echo Download interrupted, will resume on the next invocation. && echo File was: $BOOTSTRAP_CACHE_DIR/$input_file' INT
  if [[ -e $BOOTSTRAP_CACHE_DIR/$input_file ]]; then
    remote_size=$(curl -s -# --head "$remote_url" | awk '/^Content-Length:/ {print $2}' | tr -d '\r')
    local_size=$(wc -c < "$BOOTSTRAP_CACHE_DIR/$input_file")
    if ! [[ $remote_size ]]; then
      # echo "Unable to retrieve remote size: Server does not provide Content-Length" >&2
      echo "[-] Downloading ${input_file}..."
    elif [ "$remote_size" = "$local_size" ]; then
      echo "[+] Download complete, skipping ${BOOTSTRAP_CACHE_DIR}/${input_file}..." >&2
    elif [ $remote_size > $local_size ]; then
      echo "[/] Resuming download of ${input_file}..."
      curl_cmd -C - -o "$BOOTSTRAP_CACHE_DIR/$input_file" "$remote_url"
    elif [ $remote_size < $local_size ]; then
      echo "Remote file shrunk, delete local copy and start over" >&2
    fi
  else
   echo "[-] Downloading ${input_file}..."
   curl_cmd -o "$BOOTSTRAP_CACHE_DIR/$input_file" "$remote_url"
  fi
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


download_pxe() {
####################################################################
# This uses ROM-o-Matic to generate a custom PXE boot ROM.
# (doesn't use the function because of the unique curl command)
	echo "Downloading $pxe_rom"
	if ! curl $curl_options -H 'Accept-Encoding: gzip,deflate' -o "$BOOTSTRAP_CACHE_DIR/$pxe_rom" \
		"https://rom-o-matic.eu/build.fcgi" \
		-H "Origin: http://rom-o-matic.eu" -H "Host: rom-o-matic.eu" \
		-H "Content-Type: application/x-www-form-urlencoded" \
		-H "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8" \
		-H "Referer: https://rom-o-matic.eu/build.fcgi" \
		-H "Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.3" \
		--data "BINARY=80861004.rom&BINDIR=bin&REVISION=fb6b&DEBUG=&EMBED.00script.ipxe=&"; then
		echo "There was a problem downloading the PXE image"
	fi
}


# Download the PXE boot ROM image
download_pxe

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

while read -r cookbook_name cookbook_version; do
   find "${BOOTSTRAP_CACHE_DIR}/cookbooks/" -name "${cookbook_name}-\*.tar.gz" -and -not -name "${cookbook_name}-${cookbook_version}.tar.gz" -delete && true
   download_file "cookbooks/${cookbook_name}-${cookbook_version}.tar.gz" "$cookbook_base/${cookbook_name}/versions/${cookbook_version}/download"
done < <(jq -r '.packages[] | "\(.name) \(.version)"' "$packages_json")


####################################################################
# Pull knife-acl gem.
download_file knife-acl-1.0.2.gem "$ruby_gem_url/knife-acl-1.0.2.gem"


####################################################################
# Pull needed gems for fpm and fluentd.
mkdir -p "$BOOTSTRAP_CACHE_DIR"/{fpm_gems,fluentd_gems}

while read -r fpm_name fpm_version; do
   download_file "fpm_gems/${fpm_name}-${fpm_version}.gem" "$ruby_gem_url/${fpm_name}-${fpm_version}.gem"
done < <(jq -r '.fpm_gems[] | "\(.name) \(.version)"' "$rubygems_json")

while read -r fluentd_name fluentd_version; do
   download_file "fluentd_gems/${fluentd_name}-${fluentd_version}.gem" "$ruby_gem_url/${fluentd_name}-${fluentd_version}.gem"
done < <(jq -r '.fluentd_gems[] | "\(.name) \(.version)"' "$packages_json")


####################################################################
# Obtain Cirros image.
download_file "cirros-$cirros_version-x86_64-disk.img" "$cirros_url/$cirros_version/cirros-$cirros_version-x86_64-disk.img"


####################################################################
# Obtain various items used for monitoring.
# Remove obsolete kibana package
rm -f "$BOOTSTRAP_CACHE_DIR/kibana-${VER_KIBANA}-linux-x64.tar.gz"

# Remove obsolete cached items for BrightCoveOS Diamond
rm -rf "$BOOTSTRAP_CACHE_DIR/diamond"

clone_repo https://github.com/python-diamond/Diamond python-diamond "$VER_DIAMOND"
clone_repo https://github.com/mobz/elasticsearch-head elasticsearch-head "$VER_ESPLUGIN"

download_file pagerduty-zabbix-proxy.py https://gist.githubusercontent.com/ryanhoskin/202a1497c97b0072a83a/raw/96e54cecdd78e7990bb2a6cc8f84070599bdaf06/pd-zabbix-proxy.py

while read -r name version; do
        # curl_cmd "$pypi_url/${name:0:1}/${name}/${name}-${version}.tar.gz" -o $BOOTSTRAP_CACHE_DIR/"${name}-${version}.tar.gz"
        download_file "${name}-${version}.tar.gz" "$pypi_url/${name:0:1}/${name}/${name}-${version}.tar.gz"
done < <(jq -r '.monitoring[] | "\(.name) \(.version)"' "$packages_json")


####################################################################
# get calicoctl for Neutron+Calico experiments
download_file "calicoctl-${VER_CALICOCTL}" "https://github.com/projectcalico/calicoctl/releases/download/${VER_CALICOCTL}/calicoctl"
