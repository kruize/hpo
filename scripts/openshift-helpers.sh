#!/bin/bash
#
# Copyright (c) 2021, 2022 Red Hat, IBM Corporation and others.
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

###############################  v OPENSHIFT v #################################

function openshift_first() {
	#Create a namespace
	echo "Create hpo namespace ${hpo_ns}"
	kubectl create namespace ${hpo_ns}

	kubectl_cmd="kubectl -n ${hpo_ns}"
	echo "Info: One time setup - Create a service account to deploy hpo"

	${kubectl_cmd} apply -f ${HPO_SA_MANIFEST}
	check_err "Error: Failed to create service account and RBAC"

	sed -e "s|{{ HPO_NAMESPACE }}|${hpo_ns}|" ${HPO_RB_MANIFEST_TEMPLATE} > ${HPO_RB_MANIFEST}
	${kubectl_cmd} apply -f ${HPO_RB_MANIFEST}
	check_err "Error: Failed to create role binding"
}

# You can deploy using kubectl
function openshift_deploy() {
	echo
	echo "Creating environment variable in openshift cluster using configMap"
	${kubectl_cmd} apply -f ${HPO_CONFIGMAPS}/${cluster_type}-config.yaml

	echo "Info: Deploying hpo yaml to openshift cluster"

	# Replace hpo docker image in deployment yaml
	sed -e "s|{{ HPO_IMAGE }}|${HPO_CONTAINER_IMAGE}|" ${HPO_DEPLOY_MANIFEST_TEMPLATE} > ${HPO_DEPLOY_MANIFEST}

	${kubectl_cmd} apply -f ${HPO_DEPLOY_MANIFEST}
	sleep 2
	check_running hpo
	if [ "${err}" != "0" ]; then
		# Indicate deploy failed on error
		exit 1
	fi

	# Get the HPO application port in openshift
	OPENSHIFT_IP=$(${kubectl_cmd} get pods -l=app=hpo -o wide -n ${hpo_ns} -o=custom-columns=NODE:.spec.nodeName --no-headers)
	HPO_PORT=$(${kubectl_cmd} get svc hpo --no-headers -o=custom-columns=PORT:.spec.ports[*].nodePort)
	echo "Info: Access HPO at http://${OPENSHIFT_IP}:${HPO_PORT}"
	echo
}

function openshift_start() {
	echo
	echo "###   Installing hpo for openshift"
	echo

	# If hpo_ns was not set by the user
	if [ -z "$hpo_ns" ]; then
		hpo_ns="openshift-tuning"
	fi

	openshift_first
	openshift_deploy
}

function openshift_terminate() {

	# If hpo_ns was not set by the user
	if [ -z "$hpo_ns" ]; then
		hpo_ns="openshift-tuning"
	fi

	echo
	echo -n "###   Removing hpo for openshift"
	echo

	kubectl_cmd="kubectl -n ${hpo_ns}"

	echo
	echo "Removing hpo"
	${kubectl_cmd} delete -f ${HPO_DEPLOY_MANIFEST} 2>/dev/null

	echo
	echo "Removing hpo service account"
	${kubectl_cmd} delete -f ${HPO_SA_MANIFEST} 2>/dev/null

	echo
	echo "Removing hpo rolebinding"
	${kubectl_cmd} delete -f ${HPO_RB_MANIFEST} 2>/dev/null

	echo
	echo "Removing HPO configmap"
	${kubectl_cmd} delete -f ${HPO_CONFIGMAPS}/${cluster_type}-config.yaml 2>/dev/null

	rm ${HPO_DEPLOY_MANIFEST}
	rm ${HPO_RB_MANIFEST}
	echo

	echo
	echo "Removing HPO namespace"
	kubectl delete ns ${hpo_ns}
}
