#!/bin/sh
#
# cobblerd    Cobbler helper daemon
###################################

### BEGIN INIT INFO
# Provides: cobblerd
# Required-Start: $network $remote_fs
# Required-Stop: $remote_fs
# Default-Start: 2 3 4 5
# Default-Stop: 0 1 6
# Short-Description: Cobbler daemon
# Description: This is a daemon that a provides remote cobbler API
#              and status tracking
### END INIT INFO

# Sanity checks.
[ -x /usr/bin/cobblerd ] || exit 0

# Source function library.
. /lib/lsb/init-functions

SERVICE=cobblerd
PROCESS=cobblerd
CONFIG_ARGS=" "
LOCKFILE=/var/lock/$SERVICE
WSGI=/usr/share/cobbler/web/cobbler.wsgi

RETVAL=0

start() {
  echo -n "Starting cobbler daemon: "

  if pgrep -f '/usr/bin/python /usr/bin/cobblerd'; then
    return 0
  fi

  if /usr/bin/python /usr/bin/cobblerd; then
    return 0
  fi

  return 1
}

stop() {
  echo -n "Stopping cobbler daemon: "
  pkill -9 -f '/usr/bin/python /usr/bin/cobblerd' || true
}

restart() {
    stop
    start
}

# See how we were called.
case "$1" in
    start|stop|restart)
        $1
        ;;
    status)
        if [ -f $LOCKFILE ]; then
            RETVAL=0
            echo "cobblerd is running."
        else
            RETVAL=1
            echo "cobblerd is stopped."
        fi
        ;;
    condrestart)
        [ -f $LOCKFILE ] && restart || :
        ;;
    reload)
        echo "can't reload configuration, you have to restart it"
        RETVAL=$?
        ;;
    force-reload)
        restart
        ;;
    *)
        echo "Usage: $0 {start|stop|status|restart|condrestart|reload}"
        exit 1
        ;;
esac
exit $RETVAL
