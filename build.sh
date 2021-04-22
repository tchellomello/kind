#!/bin/bash
# KUBERNETES_VERSION="v1.10.0"
# MINIKUBE_VERSION="v0.28.2"
TAG_LATEST="$1"
TAG_VERSION="$2"

verify_podman_binary() {
    if hash podman 2>/dev/null; then
        POD_MANAGER="podman"
    else
        POD_MANAGER="docker"
    fi
}

if [ -z "$DOCKER_IMAGE" ]; then
	DOCKER_IMAGE="19.03.5-dind"
	echo "Defaulting $POD_MANAGER image to $DOCKER_IMAGE"
fi

if [ -z "$MINIKUBE_VERSION" ]; then
	MINIKUBE_VERSION="v1.3.1"
	echo "Defaulting Minikube version to $MINIKUBE_VERSION"
fi

if [ -z "$KUBERNETES_VERSION" ]; then
	KUBERNETES_VERSION="v1.14.8"
	echo "Defaulting Kubernetes version to $KUBERNETES_VERSION"
fi

if [ -z "$STATIC_IP" ]; then
	STATIC_IP="172.30.99.1"
	echo "Defaulting static IP to $STATIC_IP"
fi

if [ -z "$NETWORK" ]; then
	NETWORK="default"
	echo "Defaulting $POD_MANAGER network to $NETWORK"
fi

function finish {
  echo "Cleanup"
  $POD_MANAGER rm -f $CONTAINER_ID
  $POD_MANAGER volume prune -f | true
}
trap finish EXIT

set -e

verify_podman_binary

echo "Starting dind"
CONTAINER_ID=$($POD_MANAGER run --network $NETWORK --privileged -d --rm -e DOCKER_TLS_CERTDIR='' --hostname=minikube docker:$DOCKER_IMAGE dockerd)
$POD_MANAGER cp resources/entrypoint.sh $CONTAINER_ID:/entrypoint.sh
$POD_MANAGER cp resources/setup.sh $CONTAINER_ID:/setup.sh
$POD_MANAGER cp resources/start.sh $CONTAINER_ID:/start.sh
$POD_MANAGER cp resources/kubelet.sh $CONTAINER_ID:/kubelet.sh
$POD_MANAGER cp resources/supervisord.conf $CONTAINER_ID:/etc/supervisord.conf
$POD_MANAGER cp resources/sgerrand.rsa.pub $CONTAINER_ID:/etc/apk/keys/sgerrand.rsa.pub
$POD_MANAGER cp before-cluster.sh $CONTAINER_ID:/before-cluster.sh
$POD_MANAGER cp after-cluster.sh $CONTAINER_ID:/after-cluster.sh

echo "Starting setup"
$POD_MANAGER exec -e "KUBERNETES_VERSION=$KUBERNETES_VERSION" -e "MINIKUBE_VERSION=$MINIKUBE_VERSION" -e "MINIKUBE_EXTRA_ARGS" -e "STATIC_IP=$STATIC_IP" $CONTAINER_ID /setup.sh
echo "Commiting new container"
$POD_MANAGER commit \
	-c 'ENTRYPOINT ["/entrypoint.sh"]' \
	-c 'CMD ["/usr/bin/supervisord", "--nodaemon", "-c", "/etc/supervisord.conf"]' \
	-c 'ENV PATH /usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin' \
	-c 'EXPOSE 2375/tcp' \
	-c 'EXPOSE 8443/tcp' \
	-c 'EXPOSE 10080/tcp' \
	$CONTAINER_ID $TAG_LATEST

$POD_MANAGER tag $TAG_LATEST $TAG_VERSION
