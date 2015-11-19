#!/bin/bash -e

name=tftpd-hpa
if service "${name}" status | grep -qw 'start/running' ; then
    service "${name}" restart
fi
