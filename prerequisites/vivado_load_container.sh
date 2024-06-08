#! /bin/bash

# Load the vivado container image.

set -eo pipefail

if [[ ! -f "${1}" ]]; then
    echo "Please specify the location of the vivado container:"
    echo
    echo "    bazel run //prerequisites:vivado -- path_to_docker_container.tgz"
    echo
    echo "See for details: https://github.com/filmil/vivado-docker"
    echo
    exit 1
fi


echo "Loading docker container. This may take hours to complete, but needs to"
echo "be done only once."
docker load -i "${1}"
docker images | grep xilinx-vivado
