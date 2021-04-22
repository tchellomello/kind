#!/bin/bash

verify_podman_binary() {
    if hash podman 2>/dev/null; then
        POD_MANAGER="podman"
    else
        POD_MANAGER="docker"
    fi
}

verify_podman_binary


$POD_MANAGER pull nginx:1.13 # used by config-serve

# Add images here for them to be available at runtime
# for example:
# docker pull quay.io/kubernetes-ingress-controller/nginx-ingress-controller:0.9.0
