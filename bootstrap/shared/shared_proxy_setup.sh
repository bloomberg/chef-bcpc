#!/bin/bash

source "$REPO_ROOT"/bootstrap/shared/shared_functions.sh
load_configs

[ -n "$SHARED_PROXY_SETUP" ] || {
  REQUIRED_VARS=( BOOTSTRAP_HTTP_PROXY_URL BOOTSTRAP_HTTPS_PROXY_URL )
  check_for_envvars "${REQUIRED_VARS[@]}"
  
  if [[ ! -z "$BOOTSTRAP_HTTP_PROXY_URL" ]]; then
    export http_proxy="${BOOTSTRAP_HTTP_PROXY_URL}"

    curl -s --connect-timeout 10 http://www.google.com > /dev/null && true
    if [[ $? != 0 ]]; then
      echo "Error: proxy $BOOTSTRAP_HTTP_PROXY_URL non-functional for HTTP requests" >&2
      exit 1
    fi
  fi

  if [[ ! -z "$BOOTSTRAP_HTTPS_PROXY_URL" ]]; then
    export https_proxy="${BOOTSTRAP_HTTPS_PROXY_URL}"
    curl -s --connect-timeout 10 https://github.com > /dev/null && true
    if [[ $? != 0 ]]; then
      echo "Error: proxy $BOOTSTRAP_HTTPS_PROXY_URL non-functional for HTTPS requests" >&2
      exit 1
    fi
  fi
}

# State variable to avoid doing this again
export SHARED_PROXY_SETUP=1
