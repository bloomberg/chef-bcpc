# proxy setup
#
# Make sure this file defines CURL in any case
# Only define http_proxy if you will be using a proxy
#

# sample setup using a local squid cache at 10.0.1.2 - the hypervisor
# change to reflect your real proxy info
#export PROXY="10.0.1.2:3128"

export CURL='curl'
if [ -n "$PROXY" ]; then
  echo "Using a proxy at $PROXY"
  
  export http_proxy=http://${PROXY}
  export https_proxy=https://${PROXY}
  
  # to ignore SSL errors
  export GIT_SSL_NO_VERIFY=true
  export CURL="curl -k -x http://${PROXY}"
fi
