#!/bin/bash
#
# Copyright (c) 2022, 2022 Red Hat, IBM Corporation and others.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
ROOT_DIR="${PWD}"
HPO_DOCKERFILE="Dockerfile.hpo"
SEARCH_SPACE_DOCKERFILE="Dockerfile.search_space"
HPO_CONTAINER_REPO="kruize/hpo"
HPO_VERSION="0.0.8"
HPO_CONTAINER_IMAGE=${HPO_CONTAINER_REPO}:${HPO_VERSION}
SEARCH_SPACE_CONTAINER_IMAGE=${HPO_CONTAINER_REPO}_search_space:${HPO_VERSION}
DEV_MODE=0
BUILD_PARAMS="--pull --no-cache"
CONTAINER_RUNTIME="docker"

function usage() {
	echo "Usage: $0 [-d] [-v version_string][-o HPO_CONTAINER_IMAGE]"
	echo " -d: build in dev friendly mode"
	echo " -o: build with specific hpo container image name"
	echo " -ss: build with specific search space container image name"
	echo " -v: build as specific hpo version"
	exit -1
}

# Check error code from last command, exit on error
function check_err() {
	err=$?
	if [ ${err} -ne 0 ]; then
		echo "$*"
		exit -1
	fi
}

# Remove any previous images of hpo
function cleanup() {
	echo -n "Cleanup any previous kruize images..."
	eval "${CONTAINER_RUNTIME} stop hpo >/dev/null 2>/dev/null"
	sleep 5
	eval "${CONTAINER_RUNTIME} rmi $(${CONTAINER_RUNTIME} images | grep hpo | awk '{ print $3 }') >/dev/null 2>/dev/null"
	eval "${CONTAINER_RUNTIME} rmi $(${CONTAINER_RUNTIME} images | grep hpo | awk '{ printf "%s:%s\n", $1, $2 }') >/dev/null 2>/dev/null"
	echo "done"
}

function set_tags() {
	HPO_REPO=$(echo ${HPO_CONTAINER_IMAGE} | awk -F":" '{ print $1 }')
	DOCKER_TAG=$(echo ${HPO_CONTAINER_IMAGE} | awk -F":" '{ print $2 }')
	if [ -z "${DOCKER_TAG}" ]; then
		DOCKER_TAG="latest"
	fi
}

function resolve_container_runtime() {
	IFS='=' read -r -a dockerDeamonState <<< $(systemctl show --property ActiveState docker)
	[[ "${dockerDeamonState[1]}" == "inactive" ]] && CONTAINER_RUNTIME="podman"
	if ! command -v podman &> /dev/null; then
	    echo "No Container Runtime available: Docker daemon is not running and podman command could not be found"
	    exit 1
	fi
}

# Iterate through the commandline options
while getopts di:o:ss:pv: gopts
do
	case ${gopts} in
	d)
		DEV_MODE=1
		;;
	p)
		CONTAINER_COMMAND="podman-remote"
		;;
	o)
		HPO_CONTAINER_IMAGE="${OPTARG}"
		;;
	ss)
		SEARCH_SPACE_CONTAINER_IMAGE="${OPTARG}"
		;;
	v)
		HPO_VERSION="${OPTARG}"
		;;
	[?])
		usage
	esac
done

resolve_container_runtime

echo "Building with runtime: ${CONTAINER_RUNTIME}"

git pull
set_tags

# Build the docker image with the given version string
if [ ${DEV_MODE} -eq 0 ]; then
	cleanup
else
	unset BUILD_PARAMS
fi
echo ${BUILD_PARAMS}
eval "${CONTAINER_RUNTIME} build ${BUILD_PARAMS} --build-arg HPO_VERSION=${DOCKER_TAG} -t ${HPO_CONTAINER_IMAGE} -f ${HPO_DOCKERFILE} ."
check_err "Docker build of ${HPO_CONTAINER_IMAGE} failed."
eval "${CONTAINER_RUNTIME} build ${BUILD_PARAMS} -t ${SEARCH_SPACE_CONTAINER_IMAGE} -f ${SEARCH_SPACE_DOCKERFILE} ."
check_err "Docker build of ${SEARCH_SPACE_CONTAINER_IMAGE} failed."
eval "${CONTAINER_RUNTIME} images" | grep -e "TAG" -e "${HPO_REPO}" | grep "${DOCKER_TAG}"