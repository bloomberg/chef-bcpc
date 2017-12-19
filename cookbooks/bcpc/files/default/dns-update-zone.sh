#!/bin/bash

SLAVES="`cat /usr/local/etc/dns-update-slaves`"
COND=

# Name of zone to update. If empty, all zones will be updated.
ZONE=$1

# If zone argument is non-empty, apply SQL conditional clause
test -n "$ZONE" && COND="WHERE name = '$ZONE'"

mysql --defaults-file=/etc/mysql/debian.cnf -N -s -D pdns -e \
"SELECT name FROM domains $COND" | \
while read zone; do
  pdnssec increase-serial $zone >/dev/null
  for slave in $SLAVES; do
    pdns_control notify-host $zone $slave >/dev/null
  done
done
