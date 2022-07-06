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
#
##### Script for validating HPO (Hyper Parameter Optimization) /experiment_trials API #####

# Generate the curl command based on the test name passed and get the result by querying it.
# input: Test name and Trial number
function run_get_trial_json_test() {
	exp_trial=$1
	trial_num=$2
	curl="curl -H 'Accept: application/json'"
	url="$hpo_base_url/experiment_trials"
	case "${exp_trial}" in
		empty-name)
			get_trial_json=$(${curl} ''${url}'?experiment_name=%20&trial_number=0' -w '\n%{http_code}' 2>&1)
			get_trial_json_cmd="${curl} '${url}?experiment_name=%20&trial_number=0' -w '\n%{http_code}'"
			;;
		no-name)
			get_trial_json=$(${curl} ''${url}'?trial_number=0' -w '\n%{http_code}' 2>&1)
			get_trial_json_cmd="${curl} '${url}?trial_number=0' -w '\n%{http_code}'"
			;;
		null-name)
			get_trial_json=$(${curl} ''${url}'?experiment_name=null&trial_number=0' -w '\n%{http_code}' 2>&1)
			get_trial_json_cmd="${curl} '${url}?experiment_name=null&trial_number=0' -w '\n%{http_code}'"
			;;
		only-valid-name)
			get_trial_json=$(${curl} ''${url}'?experiment_name='${current_name}'' -w '\n%{http_code}' 2>&1)
			get_trial_json_cmd="${curl} '${url}?experiment_name='${current_name}'' -w '\n%{http_code}'"
			;;
		invalid-trial-number)
			get_trial_json=$(${curl} ''${url}'?experiment_id='${current_name}'&trial_number=102yrt' -w '\n%{http_code}' 2>&1)
			get_trial_json_cmd="${curl} '${url}?experiment_id='${current_name}'&trial_number=102yrt' -w '\n%{http_code}'"
			;;
		empty-trial-number)
			get_trial_json=$(${curl} ''${url}'?experiment_id='${current_name}'&trial_number=' -w '\n%{http_code}' 2>&1)
			get_trial_json_cmd="${curl} '${url}?experiment_id='${current_name}'&trial_number=' -w '\n%{http_code}'"
			;;
		no-trial-number)
			get_trial_json=$(${curl} ''${url}'?experiment_id='${current_name}'' -w '\n%{http_code}' 2>&1)
			get_trial_json_cmd="${curl} '${url}?experiment_id='${current_name}'' -w '\n%{http_code}'"
			;;
		null-trial-number)
			get_trial_json=$(${curl} ''${url}'?experiment_id='${current_name}'&trial_number=null' -w '\n%{http_code}' 2>&1)
			get_trial_json_cmd="${curl} '${url}?experiment_id='${current_name}'&trial_number=null' -w '\n%{http_code}'"
			;;
		only-valid-trial-number)
			get_trial_json=$(${curl} ''${url}'?trial_number=0' -w '\n%{http_code}' 2>&1)
			get_trial_json_cmd="${curl} '${url}?trial_number=0' -w '\n%{http_code}'"
			;;
		valid-exp-trial)
			get_trial_json=$(${curl} ''${url}'?experiment_name=petclinic-sample-2-75884c5549-npvgd&trial_number='${trial_num}'' -w '\n%{http_code}' 2>&1)
			get_trial_json_cmd="${curl} '${url}?experiment_name=petclinic-sample-2-75884c5549-npvgd&trial_number=${trial_num}' -w '\n%{http_code}'"
			;;
	esac

	echo "command used to query the experiment_trial API = ${get_trial_json_cmd}" | tee -a ${LOG_} ${LOG}
	echo "" | tee -a ${LOG_} ${LOG}
	echo "${get_trial_json}" >> ${LOG_} ${LOG}
	http_code=$(tail -n1 <<< "${get_trial_json}")
	response=$(echo -e "${get_trial_json}" | tail -2 | head -1)
	response=$(echo ${response} | cut -c 4-)
	echo "${response}" > ${result}
}


# validate obtaining trial json from RM-HPO /experiment_trials API for invalid queries
# input: test name 
function get_trial_json_invalid_tests() {
	__test_name__=$1

	SERV_LOG="${TEST_DIR}/service.log"

	# Deploy hpo
	if [ ${cluster_type} == "native" ]; then
		deploy_hpo ${cluster_type} ${SERV_LOG}
	else
		deploy_hpo ${cluster_type} ${HPO_CONTAINER_IMAGE} ${SERV_LOG}
	fi
	
	# Check if HPO services are started
	check_server_status

	IFS=' ' read -r -a get_trial_json_invalid_tests <<<  ${hpo_get_trial_json_tests[$FUNCNAME]}
	for exp_trial in "${get_trial_json_invalid_tests[@]}"
	do
		TESTS_="${TEST_DIR}/${exp_trial}"
		mkdir -p ${TESTS_}
		LOG_="${TEST_DIR}/${exp_trial}.log"
		result="${TESTS_}/${exp_trial}_result.log"

		echo "************************************* ${exp_trial} Test ****************************************" | tee -a ${LOG_} ${LOG}

		# Get the experiment id from search space JSON
		exp="valid-experiment"
		current_id=$(echo ${hpo_post_experiment_json[${exp}]} | jq '.search_space.experiment_id')
		current_name=$(echo ${hpo_post_experiment_json[${exp}]} | jq '.search_space.experiment_name')

		# Post a valid experiment to RM-HPO /experiment_trials API.
		post_experiment_json "${hpo_post_experiment_json[$exp]}"

		run_get_trial_json_test ${exp_trial}

		actual_result="${http_code}"

		expected_result_="^4[0-9][0-9]"
		expected_behaviour="RESPONSE_CODE = 4XX BAD REQUEST"

		echo "actual_result = $actual_result"
		compare_result ${exp_trial} ${expected_result_} "${expected_behaviour}"
		echo ""
		
		stop_experiment "$current_name"
	done
	
	# Stop the HPO servers
	echo "Terminating any running HPO servers..." | tee -a ${LOG_} ${LOG}
	terminate_hpo ${cluster_type} | tee -a ${LOG_} ${LOG}
	echo "Terminating any running HPO servers...Done" | tee -a ${LOG_} ${LOG}
	
	# Sleep for few seconds to reduce the ambiguity
	sleep 5
	echo "*********************************************************************************************************" | tee -a ${LOG_} ${LOG}
}

# Post a valid experiment to RM-HPO /experiment_trials API, Query it using valid experiment id and trial number and validate the result.
# input: test name
function get_trial_json_valid_tests() {
	__test_name__=$1

	SERV_LOG="${TEST_DIR}/service.log"
	# Deploy hpo
	if [ ${cluster_type} == "native" ]; then
		deploy_hpo ${cluster_type} ${SERV_LOG}
	else
		deploy_hpo ${cluster_type} ${HPO_CONTAINER_IMAGE} ${SERV_LOG}
	fi
	
	# Check if HPO services are started
	check_server_status

	IFS=' ' read -r -a get_trial_json_valid_tests <<<  ${hpo_get_trial_json_tests[$FUNCNAME]}
	for exp_trial in "${get_trial_json_valid_tests[@]}"
	do
		TESTS_="${TEST_DIR}/${FUNCNAME}"
		mkdir -p ${TESTS_}
		LOG_="${TEST_DIR}/${FUNCNAME}.log"
		result="${TESTS_}/${exp_trial}_result.log"
		expected_json="${TESTS_}/${exp_trial}_expected_json.json"

		echo "************************************* ${exp_trial} Test ****************************************" | tee -a ${LOG_} ${LOG}

		# Get the experiment id from search space JSON
		exp="valid-experiment"
		current_id=$(echo ${hpo_post_experiment_json[${exp}]} | jq '.search_space.experiment_id')
		current_name=$(echo ${hpo_post_experiment_json[${exp}]} | jq '.search_space.experiment_name')

		# Post a valid experiment to RM-HPO /experiment_trials API.
		if [ "${exp_trial}" == "valid-exp-trial" ]; then
			post_experiment_json "${hpo_post_experiment_json[$exp]}"
			trial_num="${response}"
		else
			operation_generate_subsequent
			trial_num="${response}"
		fi

		# Query the RM-HPO /experiment_trials API for valid experiment id and trial number and get the result.
		run_get_trial_json_test "valid-exp-trial" "${trial_num}"

		actual_result="${http_code}"

		expected_result_="200"
		expected_behaviour="RESPONSE_CODE = 200 OK"

		compare_result ${exp_trial} ${expected_result_} "${expected_behaviour}"

		if [[ "${failed}" -eq 0 ]]; then
			validate_exp_trial "rest"
			if [[ ${failed} -eq 1 ]]; then
				FAILED_CASES+=(${exp_trial})
			fi
		fi

		stop_experiment "$current_name"

		echo "*********************************************************************************************************" | tee -a ${LOG_} ${LOG}
	done

	# Stop the HPO servers
	echo "Terminating any running HPO servers..." | tee -a ${LOG_} ${LOG}
	terminate_hpo ${cluster_type} | tee -a ${LOG_} ${LOG}
	echo "Terminating any running HPO servers...Done" | tee -a ${LOG_} ${LOG}
	
	# Sleep for few seconds to reduce the ambiguity
	sleep 5
}

# Tests for RM-HPO GET trial JSON API
function hpo_get_trial_json(){
	for test in "${!hpo_get_trial_json_tests[@]}"
	do
		${test} "${FUNCNAME}"
	done 
}

