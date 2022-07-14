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

function usage() {
	echo
	echo "Usage: $0 [-a] [-c [docker|minikube|native|openshift]] [-o hpo container image] [-n namespace] [-d configmaps-dir ]"
	echo " -s = start(default), -t = terminate"
	echo " -c: cluster type."
	echo " -o: build with specific hpo container image name [Default - kruize/hpo:<version>]"
	echo " -n: Namespace to which hpo is deployed [Default - monitoring namespace for cluster type minikube]"
	echo " -d: Config maps directory [Default - manifests/configmaps]"
	echo " -b: install both REST and the gRPC service"
	echo " -r: install REST only"
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

# Iterate through the commandline options
while getopts ac:d:o:n:strb gopts
do
	case ${gopts} in
	a)
		non_interactive=1
		;;
	c)
		cluster_type="${OPTARG}"
		check_cluster_type
		;;
	d)
		HPO_CONFIGMAPS="${OPTARG}"
		;;
	n)
		hpo_ns="${OPTARG}"
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
	b)
		service_type="both"
		;;
	r)
		service_type="REST"
		;;
	[?])
		usage
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
