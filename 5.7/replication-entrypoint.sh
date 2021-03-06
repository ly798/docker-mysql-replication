#!/bin/bash
set -eo pipefail

cat > /etc/mysql/mysql.conf.d/repl.cnf << EOF
[mysqld]
log-bin=mysql-bin
relay-log=mysql-relay
#bind-address=0.0.0.0
#skip-name-resolve
EOF

# If there is a linked master use linked container information
if [ -n "$MASTER_PORT_3306_TCP_ADDR" ]; then
  export MASTER_HOST=$MASTER_PORT_3306_TCP_ADDR
  export MASTER_PORT=$MASTER_PORT_3306_TCP_PORT
fi


cat >/docker-entrypoint-initdb.d/init-cc-user.sh  <<'EOF'
#!/bin/bash

echo Creating container cluster user ...
mysql -u root -p -e "\
  GRANT \
    ALL PRIVILEGES \
  ON *.* \
  TO '$CC_USER'@'%' \
  IDENTIFIED BY '$CC_PASSWORD' \
  WITH GRANT OPTION; \
  FLUSH PRIVILEGES; \
"
EOF

cat >/root/.my.cnf  << EOF
[client]
user=$CC_USER
password=$CC_PASSWORD
EOF

if [ -z "$MASTER_HOST" ]; then
  export SERVER_ID=1
  cat >/docker-entrypoint-initdb.d/init-master.sh  <<'EOF'
#!/bin/bash

echo Creating replication user ...
mysql -u root -e "\
  GRANT \
    FILE, \
    SELECT, \
    SHOW VIEW, \
    LOCK TABLES, \
    RELOAD, \
    REPLICATION SLAVE, \
    REPLICATION CLIENT \
  ON *.* \
  TO '$REPLICATION_USER'@'%' \
  IDENTIFIED BY '$REPLICATION_PASSWORD'; \
  FLUSH PRIVILEGES; \
"
EOF

  cat >/docker-entrypoint-initdb.d/init-root-user.sh  <<'EOF'
#!/bin/bash

echo Update mysql root user ...
mysql -u root -p -e "\
  SET PASSWORD FOR \
  'root'@'localhost' = PASSWORD('$ROOT_PASSWORD'); \
  FLUSH PRIVILEGES; \
"

echo Disable remote root user ...
mysql -u root -p$ROOT_PASSWORD -e "\
  DROP USER 'root'@'%';
  FLUSH PRIVILEGES; \
"
EOF
else
  # TODO: make server-id discoverable
  export SERVER_ID=${SLAVE_SERVER_ID:-2}
  cp -v /init-slave.sh /docker-entrypoint-initdb.d/
  cat > /etc/mysql/mysql.conf.d/repl-slave.cnf << EOF
[mysqld]
log-slave-updates
master-info-repository=TABLE
relay-log-info-repository=TABLE
relay-log-recovery=1
EOF
fi

cat > /etc/mysql/mysql.conf.d/server-id.cnf << EOF
[mysqld]
server-id=$SERVER_ID
EOF

if [ -z "$MASTER_HOST" ]; then
  exec docker-entrypoint.sh "$@"
else
  echo $MASTER_HOST:$MASTER_PORT
  exec wait-for-it.sh $MASTER_HOST:$MASTER_PORT -t 300 -- docker-entrypoint.sh "$@"
fi

