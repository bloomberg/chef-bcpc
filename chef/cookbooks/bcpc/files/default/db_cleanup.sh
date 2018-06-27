#!/bin/bash
function error {
  echo "ERROR: $1" >&2
  log "$1"
  echo "Terminating abnormally." >&2
  log "Terminating abnormally."
  exit 1
}

function warn {
  echo "WARNING: $1" >&2
  log "$1"
}

function check_for_bin {
  if ! which $1 >/dev/null; then
    error "$1 not found on path."
  fi
}

function log {
  if ! [ -z $LOG_VERBOSE ]; then
    echo "LOG: $1"
  fi
  logger -t BCPC_DB_Cleanup "$1"
}

MYSQL=mysql
check_for_bin $MYSQL

# .my.cnf is expected to exist in the following format:
# [client]
# host=xxx
# user=xxx
# password=xxx
if [ ! -f $HOME/.my.cnf ]; then
  error "$HOME/.my.cnf not found."
fi

log "Disabling slow query logging for main databases."
$MYSQL --defaults-file=$HOME/.my.cnf --batch -e 'SET GLOBAL slow_query_log = OFF'

TABLES_TO_CLEAN_UP=( nova.virtual_interfaces nova.instance_system_metadata nova.instance_info_caches nova.security_group_instance_association )

for TABLE in ${TABLES_TO_CLEAN_UP[@]}; do
  log "Cleaning up table ${TABLE}."
  $MYSQL --defaults-file=$HOME/.my.cnf --batch -e "CREATE TABLE IF NOT EXISTS ${TABLE}_archive LIKE ${TABLE};
    START TRANSACTION;
    INSERT ${TABLE}_archive SELECT * FROM ${TABLE} WHERE deleted > 0 AND instance_uuid NOT IN (SELECT uuid FROM nova.instances WHERE deleted = 0);
    DELETE FROM ${TABLE} WHERE id IN (SELECT id FROM ${TABLE}_archive);
    COMMIT;"
done

log "Re-enabling slow query logging for main databases."
$MYSQL --defaults-file=$HOME/.my.cnf --batch -e 'SET GLOBAL slow_query_log = ON'

# ding!
log "Database cleanup complete."
