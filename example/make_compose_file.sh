#!/bin/bash
#
# this script creates nginx-stack.yaml to be used as
#   docker stack deploy -c nginx-stack.yaml {STACK_NAME}
#
NGINX_IMAGE=jwilder/nginx-proxy
# this example uses a modified image with shibboleth:
NGINX_IMAGE=gesiscss/nginx-shibboleth:v0.2.2
NGINX_NAME=nginx-shib

DOCKERGEN_IMAGE=szazs89/docker-gen:v0-merge
# OR locally built image pushed into local registry:
DOCKERGEN_IMAGE=127.0.0.1:5000/docker-gen:merge
DOCKERGEN_NAME=docker-gen

# name of the NFS server (see /etc/hosts)
NFS_SERVER=nfs_server
NFS_PATH=/mnt/nginx-proxy

cat <<EOF >nginx-stack.yaml
version: '3.8'
#
# This compose file is for stack deployment in a docker swarm
#
# Requires:
#   docker swarm init ...
#   docker node update --label-add proxy_host=true {NODE_OF_NGINX-PROXY}
# and a registry service where locally built docker image pushed up
#
services:

    ${NGINX_NAME}:
        image: ${NGINX_IMAGE}
        hostname: ${NGINX_NAME}
# this has no effect in swarm service:
        container_name: ${NGINX_NAME}

        deploy:
          replicas: 1

# add label to constrain placement on 'nodeX':
# docker node update --label-add proxy_host=true nodeX
          placement:
            constraints: [ 'node.labels.proxy_host==true' ]

          resources:
            limits:
              cpus: '1.5'
              memory: 512M
          restart_policy:
            condition: on-failure
#            max_attempts: 3
            window: 5s

# this has no effect in swarm service (see restart_policy):
        restart: unless-stopped

        command: /usr/bin/supervisord --nodaemon --configuration /etc/supervisor/supervisord.conf
        volumes:
            - shib:/etc/shibboleth
            - conf:/etc/nginx/conf.d
            - vhost:/etc/nginx/vhost.d
            - lets:/etc/nginx/certs:ro
            - /etc/ssl:/etc/ssl
        ports:
#            - 443:443 #this is not sufficient for shibboleth in swarm deployment
            - published: 443
              target: 443
              protocol: tcp
              mode: host
        networks:
            - default

    docker-gen:
        depends_on:
          - ${NGINX_NAME}
#          - registry
        image: ${DOCKERGEN_IMAGE}
        command: -notify "docker-merge-sighup ${NGINX_NAME}" -watch -wait 5s:30s /etc/docker-gen/templates/nginx.tmpl /etc/nginx/conf.d/default.conf
        hostname: ${DOCKERGEN_NAME}
#        container_name: ${DOCKERGEN_NAME}
        deploy:
          replicas: 2
          placement:
            max_replicas_per_node: 1 #requires compose version 3.8
          resources:
            limits:
              cpus: '1.5'
              memory: 512M
          restart_policy:
            condition: on-failure
#            max_attempts: 2 #for testing
            window: 5s
#        restart: unless-stopped
        volumes:
          - conf:/etc/nginx/conf.d
          - vhost:/etc/nginx/vhost.d
          - lets:/etc/nginx/certs:ro
          - /var/run/docker.sock:/tmp/docker.sock:ro
# this can be useful if local modifications are needed (assumes autofs):
#          - /net/${NFS_SERVER}/${NFS_PATH}/nginx.tmpl:/etc/docker-gen/templates/nginx.tmpl:ro
        networks:
          - default

# docker network create -d overlay --attachable {NET_NAME}
networks:
  default:
    driver: overlay
# to be able to attach other services outside of the swarm:
    attachable: true

volumes:
  shib:
    driver_opts:
       type: "nfs"
       o:    "addr=${NFS_SERVER},nolock,soft,ro"
       device: ":${NFS_PATH}/shibboleth"
  conf:
    driver_opts:
       type: "nfs"
       o:    "addr=${NFS_SERVER},nolock,soft,rw"
       device: ":${NFS_PATH}/conf.d"
  vhost:
    driver_opts:
       type: "nfs"
       o:    "addr=${NFS_SERVER},nolock,soft,ro"
       device: ":${NFS_PATH}/vhost.d"
  lets:
    driver_opts:
       type: "nfs"
       o:    "addr=${NFS_SERVER},nolock,soft,ro"
       device: ":${NFS_PATH}/letsencrypt"
EOF
