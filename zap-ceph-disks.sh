#!/bin/bash
#
# Script to reinitialise real disks on BCPC DNY cluster where disks b
# ... h are given over to Ceph
#
# location of sgdisk
TOOLPATH=/sbin
# name of sgdisk binary
DISKCOMMAND=sgdisk
# what to invoke sgdisk with
ZAPFLAGS="-Zog"
GUARDFILE=/etc/ceph-disks-zapped

if dpkg -s gdisk 2>/dev/null | grep -q Status.*installed; then
    echo "gdisk is installed"
else
    echo "install gdisk..."
    apt-get install --allow-unauthenticated -y gdisk
fi
if [[ -z `which $DISKCOMMAND` ]]; then
    echo "can't find '$DISKCOMMAND'"
    exit
fi

# Run zap command for all disks present which are not mounted
if [[ ! -f $GUARDFILE ]]; then
    # get all /dev/sd[a-z] devices mounted
    mounted_whole_disks=$(df -kh | cut -f 1 -d' ' | tail -n+2 | grep '^/dev/sd' | sed 's/[0-9]/|/' | sort -u)
    # make a regular expression of disks (e.g. /dev/sda|/dev/sdd|...|)
    mounted_disk_regex=$(for disk in $mounted_whole_disks; do echo -n $disk; done)

    for disk in $(ls /dev/sd[a-z]); do
        if ! echo "$disk" | egrep -q "${mounted_disk_regex:0:-1}"; then
            echo "#### Overwriting $disk with $DISKCOMMAND $ZAPFLAGS"
            $TOOLPATH/$DISKCOMMAND $ZAPFLAGS $disk
        else
            echo "#### Skipping mounted disk $disk"
        fi
    done
else
    echo "disks look zapped already"
fi
touch /etc/ceph-disks-zapped

