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
HPO_VERSION="0.0.1"
HPO_CONTAINER_IMAGE=${HPO_REPO}:${HPO_VERSION}

HPO_SA_MANIFEST="manifests/hpo-operator-sa.yaml"
HPO_ROLE_MANIFEST="manifests/hpo-operator-role.yaml"
HPO_RB_MANIFEST_TEMPLATE="manifests/hpo-operator-rolebinding.yaml_template"
HPO_RB_MANIFEST="manifests/hpo-operator-rolebinding.yaml"
HPO_SA_NAME="hpo-sa"
HPO_CONFIGMAPS="manifests/configmaps"
HPO_CONFIGS="manifests/hpo-configs"

#default values
setup=1
cluster_type="native"

# Default mode is interactive
non_interactive=0
hpo_ns=""
# docker: loop timeout is turned off by default
timeout=-1

# source the helpers script
. ${SCRIPTS_DIR}/cluster-helpers.sh


function usage() {
	echo
	echo "Usage: $0 [-a] [-c [docker|minikube|native]] [-h hpo container image] [-n namespace] [-d configmaps-dir ]"
	echo "       -s = start(default), -t = terminate"
	echo " -c: cluster type."
	echo " -h: build with specific hpo container image name [Default - kruize/hpo:<version>]"
	echo " -n: Namespace to which hpo is deployed [Default - monitoring namespace for cluster type minikube]"
  	echo " -d: Config maps directory [Default - manifests/configmaps]"
	exit -1
}

# Check the cluster_type
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
while getopts ac:h:n:st gopts
do
	case ${gopts} in
	a)
  		non_interactive=1
  		;;
	c)
		cluster_type="${OPTARG}"
		check_cluster_type
		;;
  	n)
		hpo_ns="${OPTARG}"
		;;
	h)
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
echo
echo "Deploying with runtime: ${CONTAINER_RUNTIME}"


# Call the proper setup function based on the cluster_type
if [ ${setup} == 1 ]; then
	${cluster_type}_start
else
	${cluster_type}_terminate
fi
