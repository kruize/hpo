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
	#	curl --silent -G -kH "Authorization: Bearer ${TOKEN}" --data-urlencode 'query=sum(node_namespace_pod_container:container_cpu_usage_seconds_total:sum_rate) by (pod)' ${URL} | jq '[ .data.result[] | [ .value[0], .metric.namespace, .metric.pod, .value[1]|tostring] | join(";") ]' | grep "${APP_NAME}" >> ${RESULTS_DIR}/cpu-${ITER}.json
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
		curl --silent -G -kH "Authorization: Bearer ${TOKEN}" --data-urlencode 'query=sum(rate(container_network_receive_bytes_total[30s])) by (pod)' ${URL} | jq '[ .data.result[] | [ .value[0], .metric.namespace, .metric.pod, .value[1]|tostring] | join(";") ]' | grep "${APP_NAME}" >> ${RESULTS_DIR}/receive_bandwidth-${ITER}.json
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
		curl --silent -G -kH "Authorization: Bearer ${TOKEN}" --data-urlencode 'query=sum(rate(container_network_transmit_bytes_total[30s])) by (pod)' ${URL} | jq '[ .data.result[] | [ .value[0], .metric.namespace, .metric.pod, .value[1]|tostring] | join(";") ]' | grep "${APP_NAME}" >> ${RESULTS_DIR}/transmit_bandwidth-${ITER}.json
		#err_exit "Error: could not get bandwidth details of the pod" >>setup.log
	done
}

## Collect total seconds taken for timed annotations of all methods
function get_app_timer_sum()
{
	URL=$1
	TOKEN=$2
	RESULTS_DIR=$3
	ITER=$4
	APP_NAME=$5
	# Delete the old json file if any
	rm -rf ${RESULTS_DIR}/app_timer_sum-${ITER}.json
	while true
	do
		# Processing curl output "timestamp value" using jq tool.
		curl --silent -G -kH "Authorization: Bearer ${TOKEN}" --data-urlencode 'query=sum(getop_timer_seconds_sum{exception="none"}) by (pod)' ${URL} | jq '[ .data.result[] | [ .value[0], .metric.namespace, .metric.pod, .value[1]|tostring] | join(";") ]' | grep "${APP_NAME}" >> ${RESULTS_DIR}/app_timer_sum-${ITER}.json
		err_exit "Error: could not get app_timer_sum details of the pod" >>setup.log
	done
}

## Collect the total count of timed annotations of all methods
function get_app_timer_count()
{
	URL=$1
	TOKEN=$2
	RESULTS_DIR=$3
	ITER=$4
	APP_NAME=$5
	# Delete the old json file if any
	rm -rf ${RESULTS_DIR}/app_timer_count-${ITER}.json
	while true
	do
		# Processing curl output "timestamp value" using jq tool.
		curl --silent -G -kH "Authorization: Bearer ${TOKEN}" --data-urlencode 'query=sum(getop_timer_seconds_count{exception="none"}) by (pod)' ${URL} | jq '[ .data.result[] | [ .value[0], .metric.namespace, .metric.pod, .value[1]|tostring] | join(";") ]' | grep "${APP_NAME}" >> ${RESULTS_DIR}/app_timer_count-${ITER}.json
		err_exit "Error: could not get app_timer_count details of the pod" >>setup.log
	done
}

## Collect the total count of timed annotations of all methods
function get_app_timer_secondspercount()
{
	URL=$1
	TOKEN=$2
	RESULTS_DIR=$3
	ITER=$4
	APP_NAME=$5
	# Delete the old json file if any
	rm -rf ${RESULTS_DIR}/app_timer_secondspercount-${ITER}.json
	while true
	do
		# Processing curl output "timestamp value" using jq tool.
		curl --silent -G -kH "Authorization: Bearer ${TOKEN}" --data-urlencode 'query=(sum(increase(getop_timer_seconds_sum{exception="none"}[30s])) by (pod))/(sum(increase(getop_timer_seconds_count{exception="none"}[30s])) by (pod))' ${URL} | jq '[ .data.result[] | [ .value[0], .metric.namespace, .metric.pod, .value[1]|tostring] | join(";") ]' | grep "${APP_NAME}" >> ${RESULTS_DIR}/app_timer_secondspercount-${ITER}.json
		err_exit "Error: could not get app_timer_secondspercount details of the pod" >>setup.log
	done
}

## Collect the max of timed annotation
function get_app_timer_max()
{
	URL=$1
	TOKEN=$2
	RESULTS_DIR=$3
	ITER=$4
	APP_NAME=$5
	# Delete the old json file if any
	rm -rf ${RESULTS_DIR}/app_timer_max-${ITER}.json
	while true
	do
		# Processing curl output "timestamp value" using jq tool.
		curl --silent -G -kH "Authorization: Bearer ${TOKEN}" --data-urlencode 'query=sum(getop_timer_seconds_max{exception="none"}) by (pod)' ${URL} | jq '[ .data.result[] | [ .value[0], .metric.namespace, .metric.pod, .value[1]|tostring] | join(";") ]' | grep "${APP_NAME}" >> ${RESULTS_DIR}/app_timer_max-${ITER}.json
		err_exit "Error: could not get app_timer_max details of the pod" >>setup.log
	done
}

## Collect the timed annotation seconds for individual methods
function get_app_timer_method_sum()
{
	URL=$1
	TOKEN=$2
	RESULTS_DIR=$3
	ITER=$4
	APP_NAME=$5
	# Delete the old json file if any
	rm -rf ${RESULTS_DIR}/app_timer_method_sum-${ITER}.json
	while true
	do
		# Processing curl output "timestamp value" using jq tool.
		curl --silent -G -kH "Authorization: Bearer ${TOKEN}" --data-urlencode 'query=getop_timer_seconds_sum{exception="none"}' ${URL} | jq '[ .data.result[] | [ .value[0], .metric.namespace, .metric.pod, .metric.method, .value[1]|tostring] | join(";") ]' | grep "${APP_NAME}" >> ${RESULTS_DIR}/app_timer_method_sum-${ITER}.json
		err_exit "Error: could not get app_timer_method_sum details of the pod" >>setup.log
	done
}

## Collect the timed annotation count for individual methods
function get_app_timer_method_count()
{
	URL=$1
	TOKEN=$2
	RESULTS_DIR=$3
	ITER=$4
	APP_NAME=$5
	# Delete the old json file if any
	rm -rf ${RESULTS_DIR}/app_timer_method_count-${ITER}.json
	while true
	do
		# Processing curl output "timestamp value" using jq tool.
		curl --silent -G -kH "Authorization: Bearer ${TOKEN}" --data-urlencode 'query=getop_timer_seconds_count{exception="none"}' ${URL} | jq '[ .data.result[] | [ .value[0], .metric.namespace, .metric.method, .metric.pod, .value[1]|tostring] | join(";") ]' | grep "${APP_NAME}" >> ${RESULTS_DIR}/app_timer_method_count-${ITER}.json
		err_exit "Error: could not get app_timer_metod_count details of the pod" >>setup.log
	done
}

## Collect the max of timed annotation for each method
function get_app_timer_method_max()
{
	URL=$1
	TOKEN=$2
	RESULTS_DIR=$3
	ITER=$4
	APP_NAME=$5
	# Delete the old json file if any
	rm -rf ${RESULTS_DIR}/app_timer_method_max-${ITER}.json
	while true
	do
		# Processing curl output "timestamp value" using jq tool.
		curl --silent -G -kH "Authorization: Bearer ${TOKEN}" --data-urlencode 'query=getop_timer_seconds_max{exception="none"}' ${URL} | jq '[ .data.result[] | [ .value[0], .metric.namespace, .metric.method, .metric.pod, .value[1]|tostring] | join(";") ]' | grep "${APP_NAME}" >> ${RESULTS_DIR}/app_timer_method_max-${ITER}.json
		err_exit "Error: could not get app_timer_method_max details of the pod" >>setup.log
	done
}

## Collect server errors
function get_server_errors()
{
	URL=$1
	TOKEN=$2
	RESULTS_DIR=$3
	ITER=$4
	APP_NAME=$5
	# Delete the old json file if any
	rm -rf ${RESULTS_DIR}/server_errors-${ITER}.json
	while true
	do
		# Processing curl output "timestamp value" using jq tool.
		curl --silent -G -kH "Authorization: Bearer ${TOKEN}" --data-urlencode 'query=sum(http_server_errors_total) by (pod)' ${URL} | jq '[ .data.result[] | [ .value[0], .metric.namespace, .metric.pod, .value[1]|tostring] | join(";") ]' | grep "${APP_NAME}" >> ${RESULTS_DIR}/server_errors-${ITER}.json
		err_exit "Error: could not get server error details of the pod" >>setup.log
	done
}

## Collect server errors
function get_server_errors_rate()
{
        URL=$1
        TOKEN=$2
        RESULTS_DIR=$3
        ITER=$4
        APP_NAME=$5
        # Delete the old json file if any
        rm -rf ${RESULTS_DIR}/server_errors-${ITER}.json
	# Processing curl output "timestamp value" using jq tool.
	curl --silent -G -kH "Authorization: Bearer ${TOKEN}" --data-urlencode 'query=sum(rate(http_server_errors_total[3m])) by (pod)' ${URL} | jq '[ .data.result[] | [ .value[0], .metric.namespace, .metric.pod, .value[1]|tostring] | join(";") ]' | grep "${APP_NAME}" >> ${RESULTS_DIR}/server_errors-rate-${ITER}.json
        err_exit "Error: could not get server error details of the pod" >>setup.log
}


## Collect http_server_requests_sum seconds for all methods
function get_server_requests_sum()
{
	URL=$1
	TOKEN=$2
	RESULTS_DIR=$3
	ITER=$4
	APP_NAME=$5
	# Delete the old json file if any
	rm -rf ${RESULTS_DIR}/server_requests_sum-${ITER}.json
	while true
	do
		# Processing curl output "timestamp value" using jq tool.
		curl --silent -G -kH "Authorization: Bearer ${TOKEN}" --data-urlencode 'query=sum(http_server_requests_seconds_sum) by (pod)' ${URL} | jq '[ .data.result[] | [ .value[0], .metric.namespace, .metric.pod, .value[1]|tostring] | join(";") ]' | grep "${APP_NAME}" >> ${RESULTS_DIR}/server_requests_sum-${ITER}.json
		err_exit "Error: could not get server_requests_sum details of the pod" >>setup.log
	done
}

## Collect server_requests_count for all methods
function get_server_requests_count()
{
	URL=$1
	TOKEN=$2
	RESULTS_DIR=$3
	ITER=$4
	APP_NAME=$5
	# Delete the old json file if any
	rm -rf ${RESULTS_DIR}/server_requests_count-${ITER}.json
	while true
	do
		# Processing curl output "timestamp value" using jq tool.
		curl --silent -G -kH "Authorization: Bearer ${TOKEN}" --data-urlencode 'query=sum(http_server_requests_seconds_count) by (pod)' ${URL} | jq '[ .data.result[] | [ .value[0], .metric.namespace, .metric.pod, .value[1]|tostring] | join(";") ]' | grep "${APP_NAME}" >> ${RESULTS_DIR}/server_requests_count-${ITER}.json
		err_exit "Error: could not get server_requests_count details of the pod" >>setup.log
	done
}

## Collect server_requests_max of all methods
function get_server_requests_max()
{
	URL=$1
	TOKEN=$2
	RESULTS_DIR=$3
	ITER=$4
	APP_NAME=$5
	# Delete the old json file if any
	rm -rf ${RESULTS_DIR}/server_requests_max-${ITER}.json
	while true
	do
		# Processing curl output "timestamp value" using jq tool.
		curl --silent -G -kH "Authorization: Bearer ${TOKEN}" --data-urlencode 'query=sum(http_server_requests_seconds_max) by (pod)' ${URL} | jq '[ .data.result[] | [ .value[0], .metric.namespace, .metric.pod, .value[1]|tostring] | join(";") ]' | grep "${APP_NAME}" >> ${RESULTS_DIR}/server_requests_max-${ITER}.json
		err_exit "Error: could not get server_requests_max details of the pod" >>setup.log
	done
}

## Collect server_requests_sum seconds for individual method
function get_server_requests_method_sum()
{
	URL=$1
	TOKEN=$2
	RESULTS_DIR=$3
	ITER=$4
	APP_NAME=$5
	# Delete the old json file if any
	rm -rf ${RESULTS_DIR}/server_requests_method_sum-${ITER}.json
	while true
	do
		# Processing curl output "timestamp value" using jq tool.
		curl --silent -G -kH "Authorization: Bearer ${TOKEN}" --data-urlencode 'query=http_server_requests_seconds_sum' ${URL} | jq '[ .data.result[] | [ .value[0], .metric.namespace, .metric.pod, .metric.outcome, .metric.status, .value[1]|tostring] | join(";") ]' | grep "${APP_NAME}" >> ${RESULTS_DIR}/server_requests_method_sum-${ITER}.json
		err_exit "Error: could not get server_requests_method_sum details of the pod" >>setup.log
	done
}

## Collect server_requests_count for individual methods
function get_server_requests_method_count()
{
	URL=$1
	TOKEN=$2
	RESULTS_DIR=$3
	ITER=$4
	APP_NAME=$5
	# Delete the old json file if any
	rm -rf ${RESULTS_DIR}/server_requests_method_count-${ITER}.json
	while true
	do
		# Processing curl output "timestamp value" using jq tool.
		curl --silent -G -kH "Authorization: Bearer ${TOKEN}" --data-urlencode 'query=http_server_requests_seconds_count' ${URL} | jq '[ .data.result[] | [ .value[0], .metric.namespace, .metric.pod, .metric.outcome, .metric.status, .value[1]|tostring] | join(";") ]' | grep "${APP_NAME}" >> ${RESULTS_DIR}/server_requests_method_count-${ITER}.json
		err_exit "Error: could not get server_requests_method_count details of the pod" >>setup.log
	done
}

## Collect server_Requests_max for all methods
function get_server_requests_method_max()
{
	URL=$1
	TOKEN=$2
	RESULTS_DIR=$3
	ITER=$4
	APP_NAME=$5
	# Delete the old json file if any
	rm -rf ${RESULTS_DIR}/server_requests_method_max-${ITER}.json
	while true
	do
		# Processing curl output "timestamp value" using jq tool.
		curl --silent -G -kH "Authorization: Bearer ${TOKEN}" --data-urlencode 'query=http_server_requests_seconds_max' ${URL} | jq '[ .data.result[] | [ .value[0], .metric.namespace, .metric.pod, .metric.outcome , .metric.status, .value[1]|tostring] | join(";") ]' | grep "${APP_NAME}" >> ${RESULTS_DIR}/server_requests_method_max-${ITER}.json
		err_exit "Error: could not get server_requests_method_max details of the pod" >>setup.log
	done
}

## Collect per second app_timer_seconds for last 1,3,5,7,9,15 and 30 mins.
function get_app_timer_sum_rate()
{
	URL=$1
	TOKEN=$2
	RESULTS_DIR=$3
	ITER=$4
	APP_NAME=$5
	# Processing curl output "timestamp value" using jq tool.
	curl --silent -G -kH "Authorization: Bearer ${TOKEN}" --data-urlencode 'query=sum(rate(getop_timer_seconds_sum{exception="none"}[1m])) by (pod)' ${URL} | jq '[ .data.result[] | [ .value[0], .metric.namespace, .metric.pod, .value[1]|tostring] | join(";") ]' | grep "${APP_NAME}" >> ${RESULTS_DIR}/app_timer_sum_rate_1m-${ITER}.json
	curl --silent -G -kH "Authorization: Bearer ${TOKEN}" --data-urlencode 'query=sum(rate(getop_timer_seconds_sum{exception="none"}[3m])) by (pod)' ${URL} | jq '[ .data.result[] | [ .value[0], .metric.namespace, .metric.pod, .value[1]|tostring] | join(";") ]' | grep "${APP_NAME}" >> ${RESULTS_DIR}/app_timer_sum_rate_3m-${ITER}.json
	curl --silent -G -kH "Authorization: Bearer ${TOKEN}" --data-urlencode 'query=sum(rate(getop_timer_seconds_sum{exception="none"}[5m])) by (pod)' ${URL} | jq '[ .data.result[] | [ .value[0], .metric.namespace, .metric.pod, .value[1]|tostring] | join(";") ]' | grep "${APP_NAME}" >> ${RESULTS_DIR}/app_timer_sum_rate_5m-${ITER}.json
	curl --silent -G -kH "Authorization: Bearer ${TOKEN}" --data-urlencode 'query=sum(rate(getop_timer_seconds_sum{exception="none"}[7m])) by (pod)' ${URL} | jq '[ .data.result[] | [ .value[0], .metric.namespace, .metric.pod, .value[1]|tostring] | join(";") ]' | grep "${APP_NAME}" >> ${RESULTS_DIR}/app_timer_sum_rate_7m-${ITER}.json
	curl --silent -G -kH "Authorization: Bearer ${TOKEN}" --data-urlencode 'query=sum(rate(getop_timer_seconds_sum{exception="none"}[9m])) by (pod)' ${URL} | jq '[ .data.result[] | [ .value[0], .metric.namespace, .metric.pod, .value[1]|tostring] | join(";") ]' | grep "${APP_NAME}" >> ${RESULTS_DIR}/app_timer_sum_rate_9m-${ITER}.json
	curl --silent -G -kH "Authorization: Bearer ${TOKEN}" --data-urlencode 'query=sum(rate(getop_timer_seconds_sum{exception="none"}[15m])) by (pod)' ${URL} | jq '[ .data.result[] | [ .value[0], .metric.namespace, .metric.pod, .value[1]|tostring] | join(";") ]' | grep "${APP_NAME}" >> ${RESULTS_DIR}/app_timer_sum_rate_15m-${ITER}.json
	curl --silent -G -kH "Authorization: Bearer ${TOKEN}" --data-urlencode 'query=sum(rate(getop_timer_seconds_sum{exception="none"}[30m])) by (pod)' ${URL} | jq '[ .data.result[] | [ .value[0], .metric.namespace, .metric.pod, .value[1]|tostring] | join(";") ]' | grep "${APP_NAME}" >> ${RESULTS_DIR}/app_timer_sum_rate_30m-${ITER}.json
}

## Collect per second app_timer_count for last 1,3,5,7,9,15 and 30 mins.
function get_app_timer_count_rate()
{
	URL=$1
	TOKEN=$2
	RESULTS_DIR=$3
	ITER=$4
	APP_NAME=$5
	# Processing curl output "timestamp value" using jq tool.
	curl --silent -G -kH "Authorization: Bearer ${TOKEN}" --data-urlencode 'query=sum(rate(getop_timer_seconds_count{exception="none"}[1m])) by (pod)' ${URL} | jq '[ .data.result[] | [ .value[0], .metric.namespace, .metric.pod, .value[1]|tostring] | join(";") ]' | grep "${APP_NAME}" >> ${RESULTS_DIR}/app_timer_count_rate_1m-${ITER}.json
	curl --silent -G -kH "Authorization: Bearer ${TOKEN}" --data-urlencode 'query=sum(rate(getop_timer_seconds_count{exception="none"}[3m])) by (pod)' ${URL} | jq '[ .data.result[] | [ .value[0], .metric.namespace, .metric.pod, .value[1]|tostring] | join(";") ]' | grep "${APP_NAME}" >> ${RESULTS_DIR}/app_timer_count_rate_3m-${ITER}.json
	curl --silent -G -kH "Authorization: Bearer ${TOKEN}" --data-urlencode 'query=sum(rate(getop_timer_seconds_count{exception="none"}[5m])) by (pod)' ${URL} | jq '[ .data.result[] | [ .value[0], .metric.namespace, .metric.pod, .value[1]|tostring] | join(";") ]' | grep "${APP_NAME}" >> ${RESULTS_DIR}/app_timer_count_rate_5m-${ITER}.json
	curl --silent -G -kH "Authorization: Bearer ${TOKEN}" --data-urlencode 'query=sum(rate(getop_timer_seconds_count{exception="none"}[7m])) by (pod)' ${URL} | jq '[ .data.result[] | [ .value[0], .metric.namespace, .metric.pod, .value[1]|tostring] | join(";") ]' | grep "${APP_NAME}" >> ${RESULTS_DIR}/app_timer_count_rate_7m-${ITER}.json
	curl --silent -G -kH "Authorization: Bearer ${TOKEN}" --data-urlencode 'query=sum(rate(getop_timer_seconds_count{exception="none"}[9m])) by (pod)' ${URL} | jq '[ .data.result[] | [ .value[0], .metric.namespace, .metric.pod, .value[1]|tostring] | join(";") ]' | grep "${APP_NAME}" >> ${RESULTS_DIR}/app_timer_count_rate_9m-${ITER}.json
	curl --silent -G -kH "Authorization: Bearer ${TOKEN}" --data-urlencode 'query=sum(rate(getop_timer_seconds_count{exception="none"}[15m])) by (pod)' ${URL} | jq '[ .data.result[] | [ .value[0], .metric.namespace, .metric.pod, .value[1]|tostring] | join(";") ]' | grep "${APP_NAME}" >> ${RESULTS_DIR}/app_timer_count_rate_15m-${ITER}.json
	curl --silent -G -kH "Authorization: Bearer ${TOKEN}" --data-urlencode 'query=sum(rate(getop_timer_seconds_count{exception="none"}[30m])) by (pod)' ${URL} | jq '[ .data.result[] | [ .value[0], .metric.namespace, .metric.pod, .value[1]|tostring] | join(";") ]' | grep "${APP_NAME}" >> ${RESULTS_DIR}/app_timer_count_rate_30m-${ITER}.json

}

#### Collect per server_requests_sum for last 1,3,5,6 mins.
function get_server_requests_sum_rate()
{
	URL=$1
	TOKEN=$2
	RESULTS_DIR=$3
	ITER=$4
	APP_NAME=$5
	# Processing curl output "timestamp value" using jq tool.
	curl --silent -G -kH "Authorization: Bearer ${TOKEN}" --data-urlencode 'query=sum(rate(http_server_requests_seconds_sum{status="200",uri="/db"}[1m])) by (pod)' ${URL} | jq '[ .data.result[] | [ .value[0], .metric.namespace, .metric.pod, .value[1]|tostring] | join(";") ]' | grep "${APP_NAME}" >> ${RESULTS_DIR}/server_requests_sum_rate_1m-${ITER}.json
	curl --silent -G -kH "Authorization: Bearer ${TOKEN}" --data-urlencode 'query=sum(rate(http_server_requests_seconds_sum{status="200",uri="/db"}[3m])) by (pod)' ${URL} | jq '[ .data.result[] | [ .value[0], .metric.namespace, .metric.pod, .value[1]|tostring] | join(";") ]' | grep "${APP_NAME}" >> ${RESULTS_DIR}/server_requests_sum_rate_3m-${ITER}.json
	curl --silent -G -kH "Authorization: Bearer ${TOKEN}" --data-urlencode 'query=sum(rate(http_server_requests_seconds_sum{status="200",uri="/db"}[5m])) by (pod)' ${URL} | jq '[ .data.result[] | [ .value[0], .metric.namespace, .metric.pod, .value[1]|tostring] | join(";") ]' | grep "${APP_NAME}" >> ${RESULTS_DIR}/server_requests_sum_rate_5m-${ITER}.json
	curl --silent -G -kH "Authorization: Bearer ${TOKEN}" --data-urlencode 'query=sum(rate(http_server_requests_seconds_sum{status="200",uri="/db"}[6m])) by (pod)' ${URL} | jq '[ .data.result[] | [ .value[0], .metric.namespace, .metric.pod, .value[1]|tostring] | join(";") ]' | grep "${APP_NAME}" >> ${RESULTS_DIR}/server_requests_sum_rate_6m-${ITER}.json
}

## Collect per second server_requests_count for last 1,3,5,6 mins.
function get_server_requests_count_rate()
{
	URL=$1
	TOKEN=$2
	RESULTS_DIR=$3
	ITER=$4
	APP_NAME=$5
	# Processing curl output "timestamp value" using jq tool.
	curl --silent -G -kH "Authorization: Bearer ${TOKEN}" --data-urlencode 'query=sum(rate(http_server_requests_seconds_count{status="200",uri="/db"}[1m])) by (pod)' ${URL} | jq '[ .data.result[] | [ .value[0], .metric.namespace, .metric.pod, .value[1]|tostring] | join(";") ]' | grep "${APP_NAME}" >> ${RESULTS_DIR}/server_requests_count_rate_1m-${ITER}.json
	curl --silent -G -kH "Authorization: Bearer ${TOKEN}" --data-urlencode 'query=sum(rate(http_server_requests_seconds_count{status="200",uri="/db"}[3m])) by (pod)' ${URL} | jq '[ .data.result[] | [ .value[0], .metric.namespace, .metric.pod, .value[1]|tostring] | join(";") ]' | grep "${APP_NAME}" >> ${RESULTS_DIR}/server_requests_count_rate_3m-${ITER}.json
	curl --silent -G -kH "Authorization: Bearer ${TOKEN}" --data-urlencode 'query=sum(rate(http_server_requests_seconds_count{status="200",uri="/db"}[5m])) by (pod)' ${URL} | jq '[ .data.result[] | [ .value[0], .metric.namespace, .metric.pod, .value[1]|tostring] | join(";") ]' | grep "${APP_NAME}" >> ${RESULTS_DIR}/server_requests_count_rate_5m-${ITER}.json
	curl --silent -G -kH "Authorization: Bearer ${TOKEN}" --data-urlencode 'query=sum(rate(http_server_requests_seconds_count{status="200",uri="/db"}[6m])) by (pod)' ${URL} | jq '[ .data.result[] | [ .value[0], .metric.namespace, .metric.pod, .value[1]|tostring] | join(";") ]' | grep "${APP_NAME}" >> ${RESULTS_DIR}/server_requests_count_rate_6m-${ITER}.json

}

function get_http_quantiles() {

        URL=$1
        TOKEN=$2
        RESULTS_DIR=$3
        ITER=$4
        APP_NAME=$5

        # Processing curl output "timestamp value" using jq tool.
        curl --silent -G -kH "Authorization: Bearer ${TOKEN}" --data-urlencode 'query=histogram_quantile(0.50, sum(rate(http_server_requests_seconds_bucket{uri="/db"}[3m])) by (le))' ${URL} | jq '[ .data.result[] | [ .value[0], .metric.namespace, .metric.pod, .value[1]|tostring] | join(";") ]' >> ${RESULTS_DIR}/http_seconds_quan_50_histo-${ITER}.json
        curl --silent -G -kH "Authorization: Bearer ${TOKEN}" --data-urlencode 'query=histogram_quantile(0.75, sum(rate(http_server_requests_seconds_bucket{uri="/db"}[3m])) by (le))' ${URL} | jq '[ .data.result[] | [ .value[0], .metric.namespace, .metric.pod, .value[1]|tostring] | join(";") ]' >> ${RESULTS_DIR}/http_seconds_quan_75_histo-${ITER}.json
        curl --silent -G -kH "Authorization: Bearer ${TOKEN}" --data-urlencode 'query=histogram_quantile(0.95, sum(rate(http_server_requests_seconds_bucket{uri="/db"}[3m])) by (le))' ${URL} | jq '[ .data.result[] | [ .value[0], .metric.namespace, .metric.pod, .value[1]|tostring] | join(";") ]' >> ${RESULTS_DIR}/http_seconds_quan_95_histo-${ITER}.json
        curl --silent -G -kH "Authorization: Bearer ${TOKEN}" --data-urlencode 'query=histogram_quantile(0.97, sum(rate(http_server_requests_seconds_bucket{uri="/db"}[3m])) by (le))' ${URL} | jq '[ .data.result[] | [ .value[0], .metric.namespace, .metric.pod, .value[1]|tostring] | join(";") ]' >> ${RESULTS_DIR}/http_seconds_quan_97_histo-${ITER}.json
        curl --silent -G -kH "Authorization: Bearer ${TOKEN}" --data-urlencode 'query=histogram_quantile(0.99, sum(rate(http_server_requests_seconds_bucket{uri="/db"}[3m])) by (le))' ${URL} | jq '[ .data.result[] | [ .value[0], .metric.namespace, .metric.pod, .value[1]|tostring] | join(";") ]' >> ${RESULTS_DIR}/http_seconds_quan_99_histo-${ITER}.json
        curl --silent -G -kH "Authorization: Bearer ${TOKEN}" --data-urlencode 'query=histogram_quantile(0.999, sum(rate(http_server_requests_seconds_bucket{uri="/db"}[3m])) by (le))' ${URL} | jq '[ .data.result[] | [ .value[0], .metric.namespace, .metric.pod, .value[1]|tostring] | join(";") ]' >> ${RESULTS_DIR}/http_seconds_quan_999_histo-${ITER}.json
        curl --silent -G -kH "Authorization: Bearer ${TOKEN}" --data-urlencode 'query=histogram_quantile(0.9999, sum(rate(http_server_requests_seconds_bucket{uri="/db"}[3m])) by (le))' ${URL} | jq '[ .data.result[] | [ .value[0], .metric.namespace, .metric.pod, .value[1]|tostring] | join(";") ]' >> ${RESULTS_DIR}/http_seconds_quan_9999_histo-${ITER}.json
        curl --silent -G -kH "Authorization: Bearer ${TOKEN}" --data-urlencode 'query=histogram_quantile(0.99999, sum(rate(http_server_requests_seconds_bucket{uri="/db"}[3m])) by (le))' ${URL} | jq '[ .data.result[] | [ .value[0], .metric.namespace, .metric.pod, .value[1]|tostring] | join(";") ]' >> ${RESULTS_DIR}/http_seconds_quan_99999_histo-${ITER}.json
	curl --silent -G -kH "Authorization: Bearer ${TOKEN}" --data-urlencode 'query=histogram_quantile(1.0, sum(rate(http_server_requests_seconds_bucket{uri="/db"}[3m])) by (le))' ${URL} | jq '[ .data.result[] | [ .value[0], .metric.namespace, .metric.pod, .value[1]|tostring] | join(";") ]' >> ${RESULTS_DIR}/http_seconds_quan_100_histo-${ITER}.json

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
export -f get_app_timer_sum get_app_timer_count get_app_timer_secondspercount get_app_timer_max get_server_errors get_server_requests_sum get_server_requests_count get_server_requests_max 
export -f get_app_timer_method_sum get_app_timer_method_count get_app_timer_method_max get_server_requests_method_sum get_server_requests_method_count get_server_requests_method_max

echo "Collecting metric data" >> ${RESULTS_DIR}/setup.log
timeout ${TIMEOUT} bash -c  "get_cpu ${URL} ${TOKEN} ${RESULTS_DIR} ${ITER} ${APP_NAME}" &
timeout ${TIMEOUT} bash -c  "get_mem_rss ${URL} ${TOKEN} ${RESULTS_DIR} ${ITER} ${APP_NAME}" &
timeout ${TIMEOUT} bash -c  "get_mem_usage ${URL} ${TOKEN} ${RESULTS_DIR} ${ITER} ${APP_NAME}" &
timeout ${TIMEOUT} bash -c  "get_fs_usage ${URL} ${TOKEN} ${RESULTS_DIR} ${ITER} ${APP_NAME}" &
timeout ${TIMEOUT} bash -c  "get_receive_bandwidth ${URL} ${TOKEN} ${RESULTS_DIR} ${ITER} ${APP_NAME}" &
timeout ${TIMEOUT} bash -c  "get_transmit_bandwidth ${URL} ${TOKEN} ${RESULTS_DIR} ${ITER} ${APP_NAME}" &

#timeout ${TIMEOUT} bash -c  "get_app_timer_sum ${URL} ${TOKEN} ${RESULTS_DIR} ${ITER} ${APP_NAME}" &
#timeout ${TIMEOUT} bash -c  "get_app_timer_count ${URL} ${TOKEN} ${RESULTS_DIR} ${ITER} ${APP_NAME}" &
#timeout ${TIMEOUT} bash -c  "get_app_timer_secondspercount ${URL} ${TOKEN} ${RESULTS_DIR} ${ITER} ${APP_NAME}" &
#timeout ${TIMEOUT} bash -c  "get_app_timer_max ${URL} ${TOKEN} ${RESULTS_DIR} ${ITER} ${APP_NAME}" &
#timeout ${TIMEOUT} bash -c  "get_server_errors ${URL} ${TOKEN} ${RESULTS_DIR} ${ITER} ${APP_NAME}" &
#timeout ${TIMEOUT} bash -c  "get_server_requests_sum ${URL} ${TOKEN} ${RESULTS_DIR} ${ITER} ${APP_NAME}" &
#timeout ${TIMEOUT} bash -c  "get_server_requests_count ${URL} ${TOKEN} ${RESULTS_DIR} ${ITER} ${APP_NAME}" &
#timeout ${TIMEOUT} bash -c  "get_server_requests_max ${URL} ${TOKEN} ${RESULTS_DIR} ${ITER} ${APP_NAME}" &
#timeout ${TIMEOUT} bash -c  "get_app_timer_method_sum ${URL} ${TOKEN} ${RESULTS_DIR} ${ITER} ${APP_NAME}" &
#timeout ${TIMEOUT} bash -c  "get_app_timer_method_count ${URL} ${TOKEN} ${RESULTS_DIR} ${ITER} ${APP_NAME}" &
#timeout ${TIMEOUT} bash -c  "get_app_timer_method_max ${URL} ${TOKEN} ${RESULTS_DIR} ${ITER} ${APP_NAME}" &
#timeout ${TIMEOUT} bash -c  "get_server_requests_method_sum ${URL} ${TOKEN} ${RESULTS_DIR} ${ITER} ${APP_NAME}" &
#timeout ${TIMEOUT} bash -c  "get_server_requests_method_count ${URL} ${TOKEN} ${RESULTS_DIR} ${ITER} ${APP_NAME}" &
#timeout ${TIMEOUT} bash -c  "get_server_requests_method_max ${URL} ${TOKEN} ${RESULTS_DIR} ${ITER} ${APP_NAME}" &
sleep ${TIMEOUT}

# Calculate the rate of metrics for the last 1,3,5,7,9,15,30 mins.
#get_app_timer_sum_rate ${URL} ${TOKEN} ${RESULTS_DIR} ${ITER} ${APP_NAME} &
#get_app_timer_count_rate ${URL} ${TOKEN} ${RESULTS_DIR} ${ITER} ${APP_NAME} &
#get_server_requests_sum_rate ${URL} ${TOKEN} ${RESULTS_DIR} ${ITER} ${APP_NAME} &
#get_server_requests_count_rate ${URL} ${TOKEN} ${RESULTS_DIR} ${ITER} ${APP_NAME} &
#get_http_quantiles ${URL} ${TOKEN} ${RESULTS_DIR} ${ITER} ${APP_NAME} &
#get_server_errors_rate ${URL} ${TOKEN} ${RESULTS_DIR} ${ITER} ${APP_NAME} &

