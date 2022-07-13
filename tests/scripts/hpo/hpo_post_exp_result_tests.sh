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
##### Script for validating HPO (Hyper Parameter Optimization) for posting experiment results using /experiment_trials API or GRPC service #####

# Post the experiment result to HPO /experiment_trials API
# input: Experiment result
# output: Create the Curl command with given JSON and get the result
function post_experiment_result_json() {
	exp_result=$1

	echo ""
	echo "*************************************"
	echo "result json array = ${exp_result}"
	echo "*************************************"
	form_hpo_api_url "experiment_trials"

	post_result=$(curl -s -H 'Content-Type: application/json' ${hpo_url}  -d "${exp_result}"  -w '\n%{http_code}' 2>&1)

	# Example curl command used to post the experiment result: curl -H "Content-Type: application/json" -d {"experiment_id" : null, "trial_number": 0, "trial_result": "success", "result_value_type": "double", "result_value": 98.78, "operation" : "EXP_TRIAL_RESULT"} http://localhost:8085/experiment_trials -w n%{http_code}
	post_exp_result_cmd="curl -s -H 'Content-Type: application/json' ${hpo_url} -d "${exp_result}" -w '\n%{http_code}'"

	echo "" | tee -a ${LOG_} ${LOG}
	echo "Command used to post the experiment result= ${post_exp_result_cmd}" | tee -a ${LOG_} ${LOG}
	echo "" | tee -a ${LOG_} ${LOG}

	echo "${post_result}" >> ${LOG_} ${LOG}

	http_code=$(tail -n1 <<< "${post_result}")
	response=$(echo -e "${post_result}" | tail -2 | head -1)
	echo "Response is ${response}" >> ${LOG_} ${LOG}
	echo "http_code = $http_code response = $response"
}

# Post duplicate experiment results to HPO /experiment_trials API and validate the result
function post_duplicate_exp_result() {
	# Get the length of the service log before the test
	log_length_before_test=$(cat ${SERV_LOG} | wc -l)

	# Post a valid experiment to HPO /experiment_trials API.
	exp="valid-experiment"
	post_experiment_json "${hpo_post_experiment_json[$exp]}"
	
	if [ "${http_code}" == "200" ]; then
		failed=0

		# Post a valid experiment result to HPO /experiment_trials API.
		experiment_result="valid-experiment-result"

		echo -n "Post the experiment result to HPO..."
		post_experiment_result_json "${hpo_post_exp_result_json[$experiment_result]}"

		# Post the duplicate experiment result to HPO /experiment_trials API.
		echo -n "Post the same experiment result to HPO again for the same experiment_name and trial number..."
		post_experiment_result_json "${hpo_post_exp_result_json[$experiment_result]}"

		actual_result="${http_code}"
		expected_result_="400"
		expected_behaviour="Requested trial exceeds the completed trial limit"

		# Extract the lines from the service log after log_length_before_test
		extract_lines=`expr ${log_length_before_test} + 1`
		cat ${SERV_LOG} | tail -n +${extract_lines} > ${TEST_SERV_LOG}

		compare_result "${FUNCNAME}" "${expected_result_}" "${expected_behaviour}" "${TEST_SERV_LOG}"
	else
		failed=1
		expected_behaviour="RESPONSE_CODE = 200 OK"
		echo "Posting valid experiment failed"
		display_result "${expected_behaviour}" "${FUNCNAME}" "${failed}"
	fi
}

# Post different experiment results to HPO /experiment_trials API for the same experiment id and validate the result
function post_same_id_different_exp_result() {
	# Get the length of the service log before the test
	log_length_before_test=$(cat ${SERV_LOG} | wc -l)

	# Post a valid experiment to HPO /experiment_trials API.
	exp="valid-experiment"
	post_experiment_json "${hpo_post_experiment_json[$exp]}"

	if [ "${http_code}" == "200" ]; then
		failed=0

		# Post a valid experiment result to HPO /experiment_trials API.
		experiment_result="valid-experiment-result"
		echo -n "Post the experiment result to HPO..."
		post_experiment_result_json "${hpo_post_exp_result_json[$experiment_result]}"

		# Post a different valid experiment result for the same experiment_name and trial number to HPO /experiment_trials API.
		experiment_result="valid-different-result"
		echo -n "Post different experiment result to HPO again for the same experiment_name and trial number..."
		post_experiment_result_json "${hpo_post_exp_result_json[$experiment_result]}"

		actual_result="${http_code}"
		expected_result_="400"
		expected_behaviour="Requested trial exceeds the completed trial limit"

		# Extract the lines from the service log after log_length_before_test
		extract_lines=`expr ${log_length_before_test} + 1`
		cat ${SERV_LOG} | tail -n +${extract_lines} > ${TEST_SERV_LOG}
		
		compare_result "${FUNCNAME}" "${expected_result_}" "${expected_behaviour}" "${TEST_SERV_LOG}"
	else
		failed=1
		expected_behaviour="RESPONSE_CODE = 200 OK"
		echo "Posting valid experiment failed"
		display_result "${expected_behaviour}" "${FUNCNAME}" "${failed}"
	fi
}

# The test does the following:
# * Post duplicate experiment results to HPO /experiment_trials API and validate the result
# * Post different experiment results to HPO /experiment_trials API for the same experiment id and validate the result
# input: Test name
function other_exp_result_post_tests() {

	SERV_LOG="${TEST_DIR}/other_exp_res_post_service.log"
	# Deploy hpo
	if [ ${cluster_type} == "native" ]; then
		deploy_hpo ${cluster_type} ${SERV_LOG}
	else
		deploy_hpo ${cluster_type} ${HPO_CONTAINER_IMAGE} ${SERV_LOG}
	fi
	
	# Check if HPO services are started
	check_server_status

	for operation in "${other_exp_result_post_tests[@]}"
	do
		TESTS_="${TEST_DIR}/${operation}"
		mkdir -p ${TESTS_}
		TEST_SERV_LOG="${TESTS_}/service.log"
		LOG_="${TEST_DIR}/${operation}.log"

		echo "************************************* ${operation} Test ****************************************" | tee -a ${LOG_} ${LOG}

		# Get the experiment id from search space JSON
		exp="valid-experiment"
		current_id=$(echo ${hpo_post_experiment_json[${exp}]} | jq '.search_space.experiment_id')
		current_name=$(echo ${hpo_post_experiment_json[${exp}]} | jq '.search_space.experiment_name')

		operation=$(echo ${operation//-/_})
		${operation}
		echo ""

      		stop_experiment "$current_name"

		echo "*********************************************************************************************************" | tee -a ${LOG_} ${LOG}
	done
	
	# Stop the HPO servers
	echo "Terminating any running HPO servers..." | tee -a ${LOG}
	terminate_hpo ${cluster_type}
	echo "Terminating any running HPO servers...Done" | tee -a ${LOG}
	
	# Sleep for few seconds to reduce the ambiguity
	sleep 5
}

# Tests for HPO /experiment_trials API POST experiment results
function hpo_post_exp_result() {
	run_post_tests ${FUNCNAME}
	other_exp_result_post_tests
}

