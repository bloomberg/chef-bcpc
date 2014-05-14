#!/bin/bash
OSD="$1"
if [[ -z "$1" ]]; then
    echo "Usage $0 osd number to remove"
    exit
fi
sudo ceph osd crush remove osd."$OSD"
sudo ceph auth del osd."$OSD"
sudo ceph osd rm "$OSD"
