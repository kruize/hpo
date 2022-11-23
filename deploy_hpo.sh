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

HPO_SCC="manifests/hpo-scc.yaml"
HPO_SA_MANIFEST="manifests/hpo-sa.yaml"
HPO_DEPLOY_MANIFEST_TEMPLATE="manifests/hpo-deployment.yaml_template"
HPO_DEPLOY_MANIFEST="manifests/hpo-deployment.yaml"
HPO_RB_MANIFEST_TEMPLATE="manifests/hpo-rolebinding.yaml_template"
HPO_RB_MANIFEST="manifests/hpo-rolebinding.yaml"
HPO_SA_NAME="hpo-sa"
HPO_CONFIGMAPS="manifests/configmaps"

#default values
setup=1
cluster_type="native"
CONTAINER_RUNTIME="docker"
non_interactive=0
hpo_ns=""
# docker: loop timeout is turned off by default
timeout=-1
service_type="both"

# source the helpers script
. ${SCRIPTS_DIR}/cluster-helpers.sh
. ${SCRIPTS_DIR}/openshift-helpers.sh
. ${SCRIPTS_DIR}/common_utils.sh

function usage() {
	echo
	echo "Usage:"
	echo " -a | --non_interactive: interactive (default)"
	echo " -s | --start: start(default) the app"
	echo " -t | --terminate: terminate the app"
	echo " -c | --cluster_type: cluster type [docker|minikube|native|openshift]]"
	echo " -o | --container_image: build with specific hpo container image name [Default - kruize/hpo:<version>]"
	echo " -n | --namespace : Namespace to which hpo is deployed [Default - monitoring namespace for cluster type minikube]"
	echo " -d | --configmaps_dir : Config maps directory [Default - manifests/configmaps]"
	echo " --both: install both REST and the gRPC service"
	echo " --rest: install REST only"
	echo " Environment Variables to be set: REGISTRY, REGISTRY_EMAIL, REGISTRY_USERNAME, REGISTRY_PASSWORD"
	echo " [Example - REGISTRY: docker.io, quay.io, etc]"
	exit -1
}

# Check the cluster_type
function check_cluster_type() {
	case "${cluster_type}" in
	docker|minikube|native|openshift)
		;;
	*)
		echo "Error: unsupported cluster type: ${cluster_type}"
		exit -1
	esac
}

VALID_ARGS=$(getopt -o ac:d:o:n:strb --long non_interactive,cluster_type:,configmaps:,container_image:,namespace:,start,terminate,rest,both -- "$@")
if [[ $? -ne 0 ]]; then
	usage
	exit 1;
fi
# safely convert the output of getopt to arguments
eval set -- "$VALID_ARGS"

# Iterate through the commandline options
while [ : ]; do
	case "$1" in
	-a | --non_interactive)
		non_interactive=1
		shift
		;;
	-c | --cluster_type)
		cluster_type="$2"
		check_cluster_type
		shift 2
		;;
	-d | --configmaps)
		HPO_CONFIGMAPS="$2"
		shift 2
		;;
	-o | --container_image)
		HPO_CONTAINER_IMAGE="$2"
		shift 2
		;;
	-n | --namespace)
		hpo_ns="$2"
		shift 2
		;;
	-s | --start)
		setup=1
		shift
		;;
	-t | --terminate)
		setup=0
		shift
		;;
	--rest)
		service_type="REST"
		shift
		;;
	--both)
		service_type="both"
		shift
		;;
	--) shift;
		break
		;;
	esac
done

# check container runtime
resolve_container_runtime

# Get Service Status
# check if user has specified any custom image else use default
if [ -n "${HPO_CONTAINER_IMAGE}" ]; then
	echo "Using version: ${HPO_VERSION}"
else
	HPO_CONTAINER_IMAGE=${HPO_REPO}:${HPO_VERSION}
fi

# Get Service Status
SERVICE_STATUS_NATIVE=$(ps -u | grep service.py | grep -v grep)
SERVICE_STATUS_DOCKER=$(${CONTAINER_RUNTIME} ps | grep hpo_docker_container)

# Call the proper setup function based on the cluster_type
if [ ${setup} == 1 ]; then
	if [ ${cluster_type} = "native" ]; then
		${cluster_type}_start ${service_type}
	else
		${cluster_type}_start
	fi
else
	${cluster_type}_terminate
fi
