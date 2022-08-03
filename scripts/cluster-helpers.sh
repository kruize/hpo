#!/bin/bash
#
# Copyright (c) 2020, 2022 Red Hat, IBM Corporation and others.
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

###############################  v Docker v #################################

function docker_start() {

	echo
	echo "Deploying with runtime: ${CONTAINER_RUNTIME}"

	echo
	echo "###   Starting HPO on Docker"
	echo
	echo ${HPO_CONTAINER_IMAGE}
	echo

	# Check if the container with name 'hpo_docker_container' is already running

	check_prereq running ${SERVICE_STATUS_DOCKER}

	${CONTAINER_RUNTIME} run -d --name hpo_docker_container -p 8085:8085 -p 50051:50051 ${HPO_CONTAINER_IMAGE} >/dev/null 2>&1
	check_err "Unexpected error occured. Service Stopped!"

	echo
	echo "### HPO Docker Service started successfully"
	echo

	sleep 2
	${CONTAINER_RUNTIME} logs hpo_docker_container
	echo
}

function docker_terminate() {

	echo
	echo "###   Removing HPO Docker Container"
	echo

	# Check if the container with name 'hpo_docker_container' is already stopped
	check_prereq stopped ${SERVICE_STATUS_DOCKER}

	${CONTAINER_RUNTIME} rm -f  hpo_docker_container >/dev/null 2>&1
	check_err "Failed to stop hpo_docker_container!"

	echo
	echo "###   Successfully Terminated"
	echo

}

###############################  v Native v #################################


function native_start() {
	echo
	echo "###   Installing HPO as a native App"
	echo

	if [ "$1" = "REST" ]; then
		req="-r rest_requirements.txt"
	else
		req="-r requirements.txt"
	fi

	echo
	echo "### Installing dependencies.........."
	echo
	python3 -m pip install --user ${req} >/dev/null 2>&1

	echo
	echo "### Starting the service..."
	echo

	# check if service is already running
	check_prereq running ${SERVICE_STATUS_NATIVE}

	if [ "$1" = "REST" ]; then
		python3 -u src/service.py "REST"
	else
		python3 -u src/service.py
	fi
}

function native_terminate() {

	echo
	echo "### Stopping HPO Service..."
	echo

	# check if service is already stopped
	check_prereq stopped ${SERVICE_STATUS_NATIVE}

	ps -u | grep service.py | grep -v grep | awk '{print $2}' | xargs kill -9 >/dev/null 2>&1
	check_err "Failed to stop HPO Service!"

	echo
	echo "### Successfully Terminated"
	echo

}

###############################  v MiniKube v #################################

function minikube_start() {
	echo
	echo "###   Installing hpo for minikube"
	echo

	# If hpo_ns was not set by the user
	if [ -z "$hpo_ns" ]; then
		hpo_ns="monitoring"
	fi

	minikube_first
	minikube_deploy
}

function minikube_first() {
	#Create a namespace
	echo "Create hpo namespace ${hpo_ns}"
	kubectl create namespace ${hpo_ns}

	kubectl_cmd="kubectl -n ${hpo_ns}"
}

# You can deploy using kubectl
function minikube_deploy() {
	echo
	echo "Creating environment variable in minikube cluster using configMap"
	${kubectl_cmd} apply -f ${HPO_CONFIGMAPS}/${cluster_type}-config.yaml

	echo "Info: Deploying hpo yaml to minikube cluster"

	# Replace hpo docker image in deployment yaml
	sed -e "s|{{ HPO_IMAGE }}|${HPO_CONTAINER_IMAGE}|" ${HPO_DEPLOY_MANIFEST_TEMPLATE} > ${HPO_DEPLOY_MANIFEST}

	${kubectl_cmd} apply -f ${HPO_DEPLOY_MANIFEST}
	sleep 2
	check_running hpo
	if [ "${err}" != "0" ]; then
		# Indicate deploy failed on error
		exit 1
	fi

	# Get the HPO application port in minikube
	MINIKUBE_IP=$(minikube ip)
	HPO_PORT=$(${kubectl_cmd} get svc hpo --no-headers -o=custom-columns=PORT:.spec.ports[*].nodePort)
	echo "Info: Access HPO at http://${MINIKUBE_IP}:${HPO_PORT}"
	echo
}

function minikube_terminate() {
	# If hpo_ns was not set by the user
	if [ -z "$hpo_ns" ]; 	then
		hpo_ns="monitoring"
	fi

	echo
	echo -n "###   Removing hpo for minikube"
	echo

	kubectl_cmd="kubectl -n ${hpo_ns}"

	echo
	echo "Removing hpo"
	${kubectl_cmd} delete -f ${HPO_DEPLOY_MANIFEST} 2>/dev/null

	echo
	echo "Removing HPO configmap"
	${kubectl_cmd} delete -f ${HPO_CONFIGMAPS}/${cluster_type}-config.yaml 2>/dev/null

	rm ${HPO_DEPLOY_MANIFEST}
	echo

	echo
	echo "Removing HPO namespace"
	kubectl delete ns ${hpo_ns}
}

###############################  utilities  #################################

function check_running() {

	check_pod=$1
	kubectl_cmd="kubectl -n ${hpo_ns}"

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
					echo "Failed to deploy HPO! Reverting changes and Exiting..."
					echo
					minikube_terminate
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
