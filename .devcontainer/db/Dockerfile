FROM alpine:3.20

RUN apk add --no-cache sqlite

COPY init.sql /docker-entrypoint/init.sql
COPY entrypoint.sh /docker-entrypoint/entrypoint.sh
RUN chmod +x /docker-entrypoint/entrypoint.sh

# The database file lives on a volume shared with the app container.
VOLUME /data
ENV SQLITE_PATH=/data/app.db

ENTRYPOINT ["/docker-entrypoint/entrypoint.sh"]
