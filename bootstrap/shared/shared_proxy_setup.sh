#!/bin/bash
# Exit immediately if anything goes wrong, instead of making things worse.

. $REPO_ROOT/bootstrap/shared/shared_functions.sh

REQUIRED_VARS=( BOOTSTRAP_HTTP_PROXY BOOTSTRAP_HTTPS_PROXY )
check_for_envvars ${REQUIRED_VARS[@]}

set -e

if [ ! -z "$BOOTSTRAP_HTTP_PROXY" ]; then
  export http_proxy=http://${BOOTSTRAP_HTTP_PROXY}
   
  curl -s --connect-timeout 10 http://www.google.com > /dev/null && true
  if [[ $? != 0 ]]; then
    echo "Error: proxy $BOOTSTRAP_HTTP_PROXY non-functional for HTTP requests" >&2
    exit 1
  fi
fi

if [ ! -z "$BOOTSTRAP_HTTPS_PROXY" ]; then
  export https_proxy=https://${BOOTSTRAP_HTTPS_PROXY}
  if [ ! -z "$BOOTSTRAP_ADDITIONAL_CACERTS_DIR" ] ; then
    # avoid polluting global cert store
    cert_args="$(find "$BOOTSTRAP_ADDITIONAL_CACERTS_DIR" \( -name '*.crt' -o -name '*.pem' \) -printf ' --cacert %p')"
  fi
  curl -s $cert_args --connect-timeout 10 https://github.com > /dev/null && true
  if [[ $? != 0 ]]; then
    echo "Error: proxy $BOOTSTRAP_HTTPS_PROXY non-functional for HTTPS requests" >&2
    exit 1
  fi
fi
