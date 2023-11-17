FROM alpine:3.15

RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories

RUN apk update \
    && apk upgrade \
    && apk add \
    tzdata \
    mariadb \
    mariadb-client \
    && cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime \
    && echo "Asia/Shanghai" > /etc/timezone \
    && apk del tzdata \
    && rm -rf /var/cache/apk/*

COPY startup.sh /startup.sh
RUN chmod +x /startup.sh

EXPOSE 3306

CMD ["/startup.sh"]