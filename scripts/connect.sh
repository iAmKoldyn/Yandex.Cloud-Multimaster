#!/bin/bash
# Simple failover connection logic for Linux
PRIMARY_HOST=${PRIMARY_HOST:-mysql-node1}
SECONDARY_HOST=${SECONDARY_HOST:-mysql-node2}
USER=${USER:-appuser}
PASSWORD=${PASSWORD:-appsecret}

mysql_check() {
    mysql --connect-timeout=5 --host="$1" -u"$USER" -p"$PASSWORD" -e "SELECT 1" >/dev/null 2>&1
}

if ! mysql_check "$PRIMARY_HOST"; then
    mysql_check "$SECONDARY_HOST"
fi
