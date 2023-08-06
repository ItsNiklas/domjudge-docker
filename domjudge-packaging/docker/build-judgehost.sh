#!/bin/sh -eu

# Check for correct number of arguments
if [ "$#" -ne 1 ]
then
        echo "Usage $0 <docker tag>"
        exit 1
fi
docker_tag="$1"

# Build the builder
docker build -t "${docker_tag}-build" -f judgehost/Dockerfile.build .

# Build chroot
builder_name=$(echo "${docker_tag}" | sed 's/[^a-zA-Z0-9_-]/-/g')
docker rm -f "${builder_name}" > /dev/null 2>&1 || echo "[DEBUG] No existing builder container found."
docker run --privileged --name "${builder_name}" --cap-add=sys_admin "${docker_tag}-build"

docker cp "${builder_name}:/chroot.tar.gz" .
docker cp "${builder_name}:/judgehost.tar.gz" .

docker rm -f "${builder_name}"
docker rmi "${docker_tag}-build"


# Build actual judgehost
docker build -t "${docker_tag}-build" -f judgehost/Dockerfile .

# Install languages

docker rm -f "${builder_name}" 2>&1 || echo "[DEBUG] No existing container found for languages installation."

docker run -it --name "${builder_name}" --privileged "${docker_tag}-build" /install_languages.sh
docker commit -c "CMD [\"/scripts/start.sh\"]" "${builder_name}" "${docker_tag}"

docker rm "${builder_name}" 2>&1 || echo "[DEBUG] No container found to remove post installation."
docker rm "${docker_tag}-build" 2>&1 || echo "[DEBUG] No container found to remove post installation."

