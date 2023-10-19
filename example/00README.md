# Usage

* deploy a registry server if needed:
    docker stack deploy -c registry.yaml {REG_STACK}
* build _docker-gen_ image in parent and push it to the local registry:
    (cd ..; docker build -t 127.0.0.1:5000/docker-gen:merge .)
    docker push 127.0.0.1:5000/docker-gen:merge
* edit variables in `make_compose_file.sh`
* create `nginx-stack.yaml`:
    ./make_compose_file.sh
* deploy `nginx-proxy` and `nginx-gen` services:
    docker stack deploy -c nginx-stack.yaml {NGINX_STACK}
