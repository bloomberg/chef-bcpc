#!/bin/bash

# remove the persistent MAC <=> iface mappings
# this will be regenernated on next boot
rm /etc/udev/rules.d/70-persistent-net.rules
