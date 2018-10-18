FROM mysql:5.7
ENV REPLICATION_USER replication
ENV REPLICATION_PASSWORD replication_pass
ENV CC_USER cc_admin
ENV CC_PASSWORD cc_admin_pass
COPY replication-entrypoint.sh /usr/local/bin/
COPY wait-for-it.sh /usr/local/bin/
COPY init-slave.sh /
COPY sources.list /etc/apt
RUN mv /etc/apt/sources.list.d/mysql.list /mysql.list && \
    apt-get update && apt-get install -y netcat
ENTRYPOINT ["replication-entrypoint.sh"]
CMD ["mysqld"]
