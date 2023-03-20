#!/bin/sh

if [ ! -d "/run/mysqld" ]; then
    mkdir -p /run/mysqld
fi

if [ -d /var/lib/mysql/mysql ]; then
    echo "[i] MySQL directory already present, skipping creation"
else
    echo "[i] MySQL data directory not found, creating initial DBs"

    mysql_install_db --user=root --datadir=/var/lib/mysql > /dev/null

    if [ "$MYSQL_ROOT_PASSWORD" = "" ]; then
        MYSQL_ROOT_PASSWORD=root
        echo "[i] MySQL root Password: $MYSQL_ROOT_PASSWORD"
    fi

    MYSQL_DATABASE=${MYSQL_DATABASE:-""}
    MYSQL_USER=${MYSQL_USER:-""}
    MYSQL_PASSWORD=${MYSQL_PASSWORD:-""}

    tfile=`mktemp`
    if [ ! -f "$tfile" ]; then
        return 1
    fi

    cat << EOF > $tfile
USE mysql;
FLUSH PRIVILEGES;
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY "$MYSQL_ROOT_PASSWORD" WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON *.* TO 'root'@'localhost' IDENTIFIED BY "$MYSQL_ROOT_PASSWORD" WITH GRANT OPTION;
EOF

    if [ "$MYSQL_DATABASE" != "" ]; then
        echo "[i] Creating database: $MYSQL_DATABASE"
        echo "CREATE DATABASE IF NOT EXISTS \`$MYSQL_DATABASE\` CHARACTER SET utf8 COLLATE utf8_general_ci;" >> $tfile

        if [ "$MYSQL_USER" != "" ]; then
            echo "[i] Creating user: $MYSQL_USER with password $MYSQL_PASSWORD"
            echo "GRANT ALL ON \`$MYSQL_DATABASE\`.* to '$MYSQL_USER'@'%' IDENTIFIED BY '$MYSQL_PASSWORD';" >> $tfile
            echo "GRANT ALL ON \`$MYSQL_DATABASE\`.* to '$MYSQL_USER'@'localhost' IDENTIFIED BY '$MYSQL_PASSWORD';" >> $tfile
        fi
    fi
    /usr/bin/mysqld --user=root --bootstrap --verbose=0 < $tfile
    rm -f $tfile
fi

MYSQL_DATABASE_BACKUP_CRON="${MYSQL_DATABASE_BACKUP_CRON:-""}"
MYSQL_DATABASE_BACKUP_DIR=${MYSQL_DATABASE_BACKUP_DIR:-""}
if [ "$MYSQL_DATABASE" != "" ] && [ "$MYSQL_USER" != "" ] && [ "$MYSQL_DATABASE_BACKUP_CRON" != "" ] && [ "$MYSQL_DATABASE_BACKUP_DIR" != "" ]; then
    
    echo "[i] Creating database backup dir"
    if [ ! -d "${MYSQL_DATABASE_BACKUP_DIR}" ]; then
        mkdir -p ${MYSQL_DATABASE_BACKUP_DIR}
    fi

    echo "[i] Creating database backup cron"
    touch /backup.sh && chmod +x /backup.sh && \
    cat << EOF > /backup.sh
    #!/bin/sh
    mysqldump -u${MYSQL_USER} -p${MYSQL_PASSWORD} --databases ${MYSQL_DATABASE} > ${MYSQL_DATABASE_BACKUP_DIR}/${MYSQL_DATABASE}_\$(date +%Y%m%d%H%M%S).sql
EOF
    cronCommand="${MYSQL_DATABASE_BACKUP_CRON}"" sh /backup.sh"
    echo "$cronCommand" > /etc/crontabs/root

    MYSQL_DATABASE_BACKUP_CLEANUP_CRON=${MYSQL_DATABASE_BACKUP_CLEANUP_CRON:-""}
    if [ "$MYSQL_DATABASE_BACKUP_CLEANUP_CRON" != "" ];then
        echo "[i] Creating database backup dir cleanup cron"
        echo "0 */1 * * * find ${MYSQL_DATABASE_BACKUP_DIR} -name '*sql' -mtime +${MYSQL_DATABASE_BACKUP_CLEANUP_CRON} | xargs rm -f" >> /etc/crontabs/root
    fi
    set -evx -o pipefail && crond
fi

exec /usr/bin/mysqld --user=root --console --skip-name-resolve --skip-networking=0