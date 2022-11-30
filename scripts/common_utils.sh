#!/bin/bash
#
# Copyright (c) 2020, 2020 Red Hat, IBM Corporation and others.
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

###############################  utilities  #################################

function check_running() {

	check_pod=$1
	check_pod_ns=$2
	cluster_type=$3
	kubectl_cmd="kubectl -n ${check_pod_ns}"

	echo "Info: Waiting for ${check_pod} to come up..."
	err_wait=0
	while true;
	do
		sleep 2
		${kubectl_cmd} get pods | grep ${check_pod}
		pod_stat=$(${kubectl_cmd} get pods | grep ${check_pod} | awk '{ print $3 }')
		case "${pod_stat}" in
			"Running")
				echo "Info: ${check_pod} deploy succeeded: ${pod_stat}"
				err=0
				break;
				;;
			"Error")
				# On Error, wait for 10 seconds before exiting.
				err_wait=$(( err_wait + 1 ))
				if [ ${err_wait} -gt 5 ]; then
					echo "Error: ${check_pod} deploy failed: ${pod_stat}"
					err=-1
					break;
				fi
				;;
			*)
				sleep 2
				if [ -z "${pod_stat}" ]; then
					echo
					echo "Failed to deploy ${check_pod}! Reverting changes and Exiting..."
					echo
					"${cluster_type}"_terminate
					exit 1
				else
					continue;
				fi
				;;
		esac
	done

	${kubectl_cmd} get pods | grep ${check_pod}
	echo
}

# Resolve Container runtime
function resolve_container_runtime() {
	IFS='=' read -r -a dockerDeamonState <<< $(systemctl show --property ActiveState docker)
	[[ "${dockerDeamonState[1]}" == "inactive" ]] && CONTAINER_RUNTIME="podman"
	if ! command -v podman &> /dev/null; then
		echo "No Container Runtime available: Docker daemon is not running and podman command could not be found"
		exit 1
	fi
}

# Check error code from last command, exit on error
function check_err() {
	err=$?
	if [ ${err} -ne 0 ]; then
		echo "$*"
		exit -1
	fi
}

# Check if service is already running
function check_prereq() {

	if [ "$1" = "running" ]; then
		if [ -n "$2" ]; then
			echo "Error: Service is already Running."
			echo
			exit -1
		fi
	else
		if [ -z "$2" ]; then
			echo "Error: Service is already Stopped."
			echo
			exit -1
		fi
	fi
}

# create kubernetes secret
function create_secret() {
	#	For Minikube/Openshift, check if registry credentials are set as Env Variables and proceed for secret creation accordingly
	if [ "${REGISTRY}" ] && [ "${REGISTRY_USERNAME}" ] && [ "${REGISTRY_PASSWORD}" ] && [ "${REGISTRY_EMAIL}" ]; then
		namespace="$1"
		echo
		# create a kube secret each time app is deployed
		kubectl create secret docker-registry hpo-registry-secret --docker-username="${REGISTRY_USERNAME}" \
		--docker-server="${REGISTRY}" --docker-email="${REGISTRY_EMAIL}"  --docker-password="${REGISTRY_PASSWORD}" \
		-n ${namespace}
		echo
		# link the secret to the service account
		kubectl patch serviceaccount hpo-sa -p '{"imagePullSecrets": [{"name": "hpo-registry-secret"}]}' -n ${namespace}
	fi
}

function check_kustomize() {
	kubectl_tool=$(which kubectl)
	check_err "Error: Please install the kubectl tool"
	# Check to see if kubectl supports kustomize
	kubectl --help | grep "kustomize" >/dev/null
	check_err "Error: Please install a newer version of kubectl tool that supports the kustomize option (>=v1.12)"
}
