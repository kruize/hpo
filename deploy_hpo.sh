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
SCRIPTS_DIR="${ROOT_DIR}/scripts"
HPO_REPO="kruize/hpo"
HPO_VERSION=$(grep -a -m 1 "HPO_VERSION" ${ROOT_DIR}/version.py | cut -d= -f2)
HPO_VERSION=$(sed -e 's/^"//' -e 's/"$//' <<<"$HPO_VERSION")
echo
echo "Using version: ${HPO_VERSION}"
HPO_CONTAINER_IMAGE=${HPO_REPO}:${HPO_VERSION}
PG_VERSION="latest"
PG_CONTAINER_IMAGE="quay.io/centos7/postgresql-13-centos7":${PG_VERSION}

#default values
setup=1
cluster_type="native"
CONTAINER_RUNTIME="docker"

# source the helpers script
. ${SCRIPTS_DIR}/cluster-helpers.sh

function usage() {
	echo
	echo "Usage: $0 [-c [docker|minikube|native]] [-o hpo container image]"
	echo "       -s = start(default), -t = terminate"
	echo " -c: cluster type."
	echo " -o: build with specific hpo container image name [Default - kruize/hpo:<version>]"
	exit -1
}

# Check if the cluster_type is one of icp or openshift
function check_cluster_type() {
	case "${cluster_type}" in
	docker|minikube|native)
		;;
	*)
		echo "Error: unsupported cluster type: ${cluster_type}"
		exit -1
	esac
}

# Iterate through the commandline options
while getopts c:o:st gopts
do
	case ${gopts} in
	c)
		cluster_type="${OPTARG}"
		check_cluster_type
		;;
	o)
		HPO_CONTAINER_IMAGE="${OPTARG}"
		;;
	s)
		setup=1
		;;
	t)
		setup=0
		;;
	[?])
		usage
	esac
done

resolve_container_runtime

# Get Service Status 
SERVICE_STATUS_NATIVE=$(ps -u | grep service.py | grep -v grep)
SERVICE_STATUS_DOCKER=$(${CONTAINER_RUNTIME} ps | grep hpo_docker_container)
SERVICE_STATUS_DATABASE=$(${CONTAINER_RUNTIME} ps | grep postgresql_HPO_DB)

# Call the proper setup function based on the cluster_type
if [ ${setup} == 1 ]; then
    # Start DB Server first
    database_start
	${cluster_type}_start
else
    # Stop DB Server
    database_terminate
	${cluster_type}_terminate
fi
