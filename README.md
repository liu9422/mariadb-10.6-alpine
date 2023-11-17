# 基于Alpine的MariaDB镜像

> Alpine：3.15 

> MariaDB：10.6.14

用于个人测试部署或小型应用

## 使用方式

```shell
docker pull liuchengjun94222/mariadb-10.6.14-alpine:latest
```
或直接clone本项目后在本地构建
```shell
docker build -t mariadb-10.6.14-alpine .
```

### 创建镜像
```shell
docker run -itd \
    -p 3306:3306 \
    -e MYSQL_ROOT_PASSWORD="root_password" \  # 数据库用户Root的密码，可缺省，默认为root
    -e MYSQL_DATABASE="database_name" \  # 初始化数据库名称，缺省时将不创建
    -e MYSQL_USER="username" \  # 初始化数据库用户名称，数据库缺省时将不创建
    -e MYSQL_PASSWORD="password" \   # 初始化数据库用户名称密码，数据库缺省时将不创建
    -e MYSQL_DATABASE_BACKUP_CRON="* * * * *" \  # 初始化数据库的自定义备份任务配置，缺省时将不进行数据库定时备份
    -e MYSQL_DATABASE_BACKUP_DIR="/backup_data" \  # 初始化数据库的自定义备份数据地址，缺省时将不进行数据库定时备份
    -e MYSQL_DATABASE_BACKUP_CLEANUP_CRON="7" \  # 初始化数据库的清理备份数据任务时间，单位为天，超过该时间备份文件被删除
    -v /mysql_data:/var/lib/mysql \   # 将主机/mysql_data挂载到容器的/var/lib/mysql，当/mysql_data存在数据文件时将不再进行数据库初始化工作
    -v /mysql_backup_data:/backup_data \  # 将主机/mysql_backup_data挂载到容器的/backup_data，保存备份的数据文件
    mariadb-10.6.14-alpine
```
