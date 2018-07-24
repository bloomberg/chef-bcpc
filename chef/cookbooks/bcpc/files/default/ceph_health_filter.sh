#!/bin/bash

BLOCKED_OP_RE='osds\ have\ slow\ request|(ops|requests)\ are\ blocked'

STDIN=$(cat)

# Report Ceph health output verbatim if it is not HEALTH_WARN
echo $STDIN | grep -q ^HEALTH_WARN >/dev/null 2>&1 \
  || { echo "$STDIN" && exit 0; }

if [ "`echo "$STDIN" | egrep -vc \"$BLOCKED_OP_RE\"`" -gt 0 ]; then
  STDIN=`echo "$STDIN" | sed 's/^HEALTH_WARN/HEALTH_WARN_non_blocked/'`
else
  STDIN=`echo "$STDIN" | sed 's/^HEALTH_WARN/HEALTH_WARN_blocked/'`
fi

echo "$STDIN"
