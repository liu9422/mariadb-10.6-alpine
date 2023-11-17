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

if [ ! -f "/etc/my.cnf" ]; then
    touch /etc/my.cnf
fi

cpu_count=$(grep -c ^processor /proc/cpuinfo)
thread_concurrency=$(expr $cpu_count \* 2)

cat << EOF > /etc/my.cnf
# This group is read both both by the client and the server
# use it for options that affect everything
[client-server]

# This group is read by the server
[mysqld]
open_files_limit = 65535 
#skip-locking
skip-external-locking                           #跳过外部锁定
back_log=3000                                   #暂存的连接数量
skip-name-resolve                               #关闭mysql的dns反查功能
memlock                                         #将mysqld 进程锁定在内存中
lower_case_table_names = 1
#query_response_time_stats=1
#core-file
#core-file-size = unlimited
query_cache_type=1                              #查询缓存  (0 = off、1 = on、2 = demand)
performance_schema=0                            #收集数据库服务器性能参数
net_read_timeout=3600                           #连接繁忙阶段（query）起作用
net_write_timeout=3600                          #连接繁忙阶段（query）起作用
key_buffer_size = 32M                           #设置索引块缓存大小
max_allowed_packet = 128M                       #通信缓冲大小
table_open_cache = 1024                         #table高速缓存的数量
sort_buffer_size = 12M                          #每个connection（session）第一次需要使用这个buffer的时候，一次性分配设置的内存
read_buffer_size = 8M                           #顺序读取数据缓冲区使用内存
#sort_buffer_size = 32M
#read_buffer_size = 32M
read_rnd_buffer_size = 32M                      #随机读取数据缓冲区使用内存
myisam_sort_buffer_size = 32M                   #MyISAM表发生变化时重新排序所需的缓冲
thread_cache_size = 120                         #重新利用保存在缓存中线程的数量
query_cache_size = 64M
join_buffer_size = 8M                           #Join操作使用内存
bulk_insert_buffer_size = 32M                   #批量插入数据缓存大小
delay_key_write=ON                              #在表关闭之前，将对表的update操作指跟新数据到磁盘，而不更新索引到磁盘，把对索引的更改记录在内存。这样MyISAM表可以使索引更新更快。在关闭表的时候一起更新索引到磁盘
delayed_insert_limit=4000
delayed_insert_timeout=600
delayed_queue_size=4000
# Try number of CPU's*2 for thread_concurrency
# The variable only affects Solaris!
thread_concurrency = ${thread_concurrency}      #CPU核数 * 2
max_connections=2000                            #最大连接（用户）数。每个连接MySQL的用户均算作一个连接
max_connect_errors=30                           #最大失败连接限制
interactive_timeout=600                         #服务器关闭交互式连接前等待活动的秒数
wait_timeout=3600                               #服务器关闭非交互连接之前等待活动的秒数
slow_query_log                                  #慢查询记录日志
long_query_time = 0.1                           #慢查询记录时间  0.1秒
# Disabling symbolic-links is recommended to prevent assorted security risks
symbolic-links=0

# include all files from the config directory
!includedir /etc/my.cnf.d

EOF

exec /usr/bin/mysqld --user=root --console --skip-name-resolve --skip-networking=0