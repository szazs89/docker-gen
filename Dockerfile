#FROM nginxproxy/docker-gen:latest
FROM jwilder/docker-gen:latest

RUN apk --update add bash curl jq netcat-openbsd && rm -rf /var/cache/apk/*

COPY docker-merge-sighup /usr/local/bin/
COPY docker-gen.wrapper /usr/local/bin/
COPY nginx.tmpl /etc/docker-gen/templates/

ENTRYPOINT [ "/usr/local/bin/docker-gen.wrapper" ]
