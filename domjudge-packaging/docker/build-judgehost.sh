#!/bin/sh -eu

# Check for correct number of arguments
if [ "$#" -ne 1 ]
then
        echo "Usage $0 <docker tag>"
        exit 1
fi
docker_tag="$1"
echo "[DEBUG] Assigned Docker tag: ${docker_tag}"

# Build the builder
echo "[DEBUG] Initiating the builder build process..."
docker build -t "${docker_tag}-build" -f judgehost/Dockerfile.build .
echo "[DEBUG] Finished building the builder."

# Build chroot
echo "[DEBUG] Initiating chroot build..."
builder_name=$(echo "${docker_tag}" | sed 's/[^a-zA-Z0-9_-]/-/g')
echo "[DEBUG] Builder name generated: ${builder_name}"
echo "[DEBUG] Removing existing builder container if exists..."
docker rm -f "${builder_name}" > /dev/null 2>&1 || echo "[DEBUG] No existing builder container found."
echo "[DEBUG] Running builder container..."
docker run --privileged --name "${builder_name}" --cap-add=sys_admin "${docker_tag}-build"
echo "[DEBUG] Finished running builder container."

echo "[DEBUG] Copying chroot.tar.gz from builder container..."
docker cp "${builder_name}:/chroot.tar.gz" .
echo "[DEBUG] Completed copying chroot.tar.gz."

echo "[DEBUG] Copying judgehost.tar.gz from builder container..."
docker cp "${builder_name}:/judgehost.tar.gz" .
echo "[DEBUG] Completed copying judgehost.tar.gz."

echo "[DEBUG] Removing builder container..."
docker rm -f "${builder_name}"
echo "[DEBUG] Removed builder container."

echo "[DEBUG] Removing builder image..."
docker rmi "${docker_tag}-build"
echo "[DEBUG] Removed builder image."

# Build actual judgehost
echo "[DEBUG] Building the actual judgehost image..."
docker build -t "${docker_tag}-build" -f judgehost/Dockerfile .
echo "[DEBUG] Finished building the judgehost image."

# Install languages
echo "[DEBUG] Removing existing builder container for languages installation if exists..."
docker rm -f "${builder_name}" 2>&1 || echo "[DEBUG] No existing container found for languages installation."
echo "[DEBUG] Running builder container for languages installation..."
docker run -it --name "${builder_name}" --privileged "${docker_tag}-build" /install_languages.sh
echo "[DEBUG] Finished languages installation in the container."

echo "[DEBUG] Committing the changes in the container with CMD..."
docker commit -c "CMD [\"/scripts/start.sh\"]" "${builder_name}" "${docker_tag}"
echo "[DEBUG] Committed the changes."

echo "[DEBUG] Removing the container post installation..."
docker rm "${builder_name}" 2>&1 || echo "[DEBUG] No container found to remove post installation."

echo "[DEBUG] All tasks completed!"
