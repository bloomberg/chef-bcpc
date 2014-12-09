
#!/bin/bash -e

hash -r
PROG=${0##*/}

usage(){
    local ret=${1:-0}
    if [ $ret -eq 0 ] ; then
        exec 3>&1
    else 
        exec 3>&2
    fi
    cat <<EoF >&3
${PROG} path-to-keyfile
EoF
    exec 3>&-
    exit ${ret}
}

keypath="${1:-$HOME/.ssh/id_rsa.bcpc}"
distroot=/var/www/cobbler/pub/keys

yes | ssh-keygen -N '' -f "${keypath}"
install -D "${keypath}.pub" "${distroot}/root"
