#!/bin/bash
#
# Copyright (c) 2020, 2021 IBM Corporation, RedHat and others.
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
### Script to get pod and cluster information through prometheus queries###
#
# checks if the previous command is executed successfully
# input:Return value of previous command
# output:Prompts the error message if the return value is not zero
function err_exit() 
{
	if [ $? != 0 ]; then
		printf "$*"
		echo 
		exit -1
	fi
}

## Collect CPU data
function get_cpu()
{
	URL=$1
	TOKEN=$2
	RESULTS_DIR=$3
	ITER=$4
	APP_NAME=$5
	# Delete the old json file if any
	rm -rf ${RESULTS_DIR}/cpu-${ITER}.json
	while true
	do
		# Processing curl output "timestamp value" using jq tool.
		curl --silent -G -kH "Authorization: Bearer ${TOKEN}" --data-urlencode 'query=sum(rate(container_cpu_usage_seconds_total{image!=""}[1m])) by (pod,namespace)' ${URL} | jq '[ .data.result[] | [ .value[0], .metric.namespace, .metric.pod, .value[1]|tostring] | join(";") ]' | grep "${APP_NAME}" >> ${RESULTS_DIR}/cpu-${ITER}.json
		#err_exit "Error: could not get cpu details of the pod" >>setup.log
	done
}

## Collect MEM_RSS
function get_mem_rss()
{
	URL=$1
	TOKEN=$2
	RESULTS_DIR=$3
	ITER=$4
	APP_NAME=$5
	# Delete the old json file if any
	rm -rf ${RESULTS_DIR}/mem-${ITER}.json
	while true
	do
		# Processing curl output "timestamp value" using jq tool.
		curl --silent -G -kH "Authorization: Bearer ${TOKEN}" --data-urlencode 'query=sum(node_namespace_pod_container:container_memory_rss) by (pod)' ${URL} | jq '[ .data.result[] | [ .value[0], .metric.namespace, .metric.pod, .value[1]|tostring] | join(";") ]' | grep "${APP_NAME}" >> ${RESULTS_DIR}/mem-${ITER}.json
		err_exit "Error: could not get memory details of the pod" >>setup.log
	done
}

## Collect Memory Usage
function get_mem_usage()
{
	URL=$1
	TOKEN=$2
	RESULTS_DIR=$3
	ITER=$4
	APP_NAME=$5
	# Delete the old json file if any
	rm -rf ${RESULTS_DIR}/memusage-${ITER}.json
	while true
	do
		# Processing curl output "timestamp value" using jq tool.
		curl --silent -G -kH "Authorization: Bearer ${TOKEN}" --data-urlencode 'query=sum(container_memory_working_set_bytes) by (pod)' ${URL} | jq '[ .data.result[] | [ .value[0], .metric.namespace, .metric.pod, .value[1]|tostring] | join(";") ]' | grep "${APP_NAME}" >> ${RESULTS_DIR}/memusage-${ITER}.json
		err_exit "Error: could not get memory details of the pod" >>setup.log
	done
}

## Collect Disk Usage
function get_fs_usage()
{
	URL=$1
	TOKEN=$2
	RESULTS_DIR=$3
	ITER=$4
	APP_NAME=$5
	# Delete the old json file if any
	rm -rf ${RESULTS_DIR}/fsusage-${ITER}.json
	while true
	do
		# Processing curl output "timestamp value" using jq tool.
		curl --silent -G -kH "Authorization: Bearer ${TOKEN}" --data-urlencode 'query=sum(container_fs_usage_bytes) by (pod)' ${URL} | jq '[ .data.result[] | [ .value[0], .metric.namespace, .metric.pod, .value[1]|tostring] | join(";") ]' | grep "${APP_NAME}" >> ${RESULTS_DIR}/fsusage-${ITER}.json
		# err_exit "Error: could not get file system usage details of the pod" >>setup.log
	done
}

## Collect network bytes received
function get_receive_bandwidth()
{
	URL=$1
	TOKEN=$2
	RESULTS_DIR=$3
	ITER=$4
	APP_NAME=$5
	# Delete the old json file if any
	rm -rf ${RESULTS_DIR}/receive_bandwidth-${ITER}.json
	while true
	do
		# Processing curl output "timestamp value" using jq tool.
		curl --silent -G -kH "Authorization: Bearer ${TOKEN}" --data-urlencode 'query=sum(rate(container_network_receive_bytes_total[60s])) by (pod)' ${URL} | jq '[ .data.result[] | [ .value[0], .metric.namespace, .metric.pod, .value[1]|tostring] | join(";") ]' | grep "${APP_NAME}" >> ${RESULTS_DIR}/receive_bandwidth-${ITER}.json
		#err_exit "Error: could not get bandwidth details of the pod" >>setup.log
	done
}

## Collect network bytes transmitted
function get_transmit_bandwidth()
{
	URL=$1
	TOKEN=$2
	RESULTS_DIR=$3
	ITER=$4
	APP_NAME=$5
	# Delete the old json file if any
	rm -rf ${RESULTS_DIR}/transmit_bandwidth-${ITER}.json
	while true
	do
		# Processing curl output "timestamp value" using jq tool.
		curl --silent -G -kH "Authorization: Bearer ${TOKEN}" --data-urlencode 'query=sum(rate(container_network_transmit_bytes_total[60s])) by (pod)' ${URL} | jq '[ .data.result[] | [ .value[0], .metric.namespace, .metric.pod, .value[1]|tostring] | join(";") ]' | grep "${APP_NAME}" >> ${RESULTS_DIR}/transmit_bandwidth-${ITER}.json
		#err_exit "Error: could not get bandwidth details of the pod" >>setup.log
	done
}

ITER=$1
TIMEOUT=$2
RESULTS_DIR=$3
BENCHMARK_SERVER=$4
APP_NAME=$5
CLUSTER_TYPE=$6

mkdir -p ${RESULTS_DIR}
#QUERY_APP=prometheus-k8s-openshift-monitoring.apps
if [[ ${CLUSTER_TYPE} == "openshift" ]]; then
	QUERY_APP=thanos-querier-openshift-monitoring.apps
	URL=https://${QUERY_APP}.${BENCHMARK_SERVER}/api/v1/query
	TOKEN=`oc whoami --show-token`
elif [[ ${CLUSTER_TYPE} == "minikube" ]]; then
	echo "Minikube benchmark server = $BENCHMARK_SERVER"
	#QUERY_IP=`minikibe ip`
	QUERY_APP="${BENCHMARK_SERVER}:9090"
	URL=http://${QUERY_APP}/api/v1/query
	TOKEN=TOKEN
fi

export -f err_exit get_cpu get_mem_rss get_mem_usage get_receive_bandwidth get_transmit_bandwidth get_fs_usage

echo "Collecting metric data" >> ${RESULTS_DIR}/setup.log
timeout ${TIMEOUT} bash -c  "get_cpu ${URL} ${TOKEN} ${RESULTS_DIR} ${ITER} ${APP_NAME}" &
timeout ${TIMEOUT} bash -c  "get_mem_rss ${URL} ${TOKEN} ${RESULTS_DIR} ${ITER} ${APP_NAME}" &
timeout ${TIMEOUT} bash -c  "get_mem_usage ${URL} ${TOKEN} ${RESULTS_DIR} ${ITER} ${APP_NAME}" &
timeout ${TIMEOUT} bash -c  "get_fs_usage ${URL} ${TOKEN} ${RESULTS_DIR} ${ITER} ${APP_NAME}" &
timeout ${TIMEOUT} bash -c  "get_receive_bandwidth ${URL} ${TOKEN} ${RESULTS_DIR} ${ITER} ${APP_NAME}" &
timeout ${TIMEOUT} bash -c  "get_transmit_bandwidth ${URL} ${TOKEN} ${RESULTS_DIR} ${ITER} ${APP_NAME}" &

sleep ${TIMEOUT}


