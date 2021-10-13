#!/bin/bash

# This script checks whether the amount of memory used by ProxySQL's query
# digest table exceeds the specified percentage of the server's total RAM. If
# so, the query digest table is reset.

set -e
set -o pipefail
set -u
#set -x

# Execute 'log_exit' when the script exits
trap 'log_exit ${?}' EXIT

# If the script exits with an error, log it to stderr (picked up by ProxySQL)
log_exit() {
    if [ "${1}" != "0" ]; then
        >&2 echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] check-query-digest.sh failed with status code ${1}"
    fi
    exit "${1}"
}

# The percent of total physical memory allowed to be used by the query digest
# before relevant table is cleared
THRESHOLD="${1}"
# The amount of physical memory on the system in bytes
PHYSICAL_MEMORY=$(free -b | awk '/^Mem:/{print $2}')
# The amount of memory used by the query digest table in bytes
QUERY_DIGEST_SIZE=$(mysql --defaults-file=/etc/proxysql-admin.cnf -Nse \
    "SELECT Variable_value FROM stats.stats_memory_metrics \
    WHERE Variable_name='query_digest_memory'")
# The percentage of physical memory required to store the entire query digest
PERCENT_USED=$(echo "scale=4; (${QUERY_DIGEST_SIZE}/${PHYSICAL_MEMORY})*100" \
    | bc)

# Clear the query digest table iff THRESHOLD has been exceeded
if (( $(echo "${PERCENT_USED} > ${THRESHOLD}" | bc -l) )); then
    mysql --defaults-file=/etc/proxysql-admin.cnf -Nse \
        "SELECT COUNT(*) FROM stats.stats_mysql_query_digest_reset"
fi
