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

# Post a JSON object to HPO(Hyper Parameter Optimization) module
# input: JSON object
# output: Create the Curl command with given JSON and get the result
function post_experiment_json() {
	json_array_=$1
	echo ""
	echo "******************************************"
	echo "json array = ${json_array_}"
	echo "******************************************"

	form_hpo_api_url "experiment_trials"

	post_cmd=$(curl -s -H 'Content-Type: application/json' ${hpo_url}  -d "${json_array_}"  -w '\n%{http_code}' 2>&1)

	# Example curl command: curl -v -s -H 'Content-Type: application/json' http://localhost:8085/experiment_trials -d '{"operation":"EXP_TRIAL_GENERATE_NEW","search_space":{"experiment_name":"petclinic-sample-2-75884c5549-npvgd","experiment_id":"a123","value_type":"double","hpo_algo_impl":"optuna_tpe","objective_function":"transaction_response_time","tunables":[{"value_type":"double","lower_bound":150,"name":"memoryRequest","upper_bound":300,"step":1},{"value_type":"double","lower_bound":1,"name":"cpuRequest","upper_bound":3,"step":0.01}],"slo_class":"response_time","direction":"minimize"}}' 

	post_experiment_cmd="curl -s -H 'Content-Type: application/json' ${hpo_url} -d '${json_array_}'  -w '\n%{http_code}'"

	echo "" | tee -a ${LOG_} ${LOG}
	echo "Curl command used to post the experiment = ${post_experiment_cmd}" | tee -a ${LOG_} ${LOG}
	echo "" | tee -a ${LOG_} ${LOG}

	echo "${post_cmd}" >> ${LOG_} ${LOG}


	http_code=$(tail -n1 <<< "${post_cmd}")
	response=$(echo -e "${post_cmd}" | tail -2 | head -1)

	echo "Response is ${response}" >> ${LOG_} ${LOG}
	echo "http_code is $http_code Response is ${response}"
}

# The test does the following:
# In case of hpo_post_experiment test, Post valid and invalid experiments to HPO /experiment_trials API and validate the reslut
# In case of hpo_post_exp_result test, Post valid and invalid experiments results to HPO /experiment_trials API and validate the result
# input: Test name
function run_post_tests(){
	hpo_test_name=$1
	
	if [ "${hpo_test_name}" == "hpo_post_experiment" ]; then
		exp_tests=("${run_post_experiment_tests[@]}")
	else
		exp_tests=("${run_post_exp_result_tests[@]}")
	fi

	SERV_LOG="${TEST_DIR}/service.log"
	# Deploy hpo
	if [ ${cluster_type} == "native" ]; then
		deploy_hpo ${cluster_type} ${SERV_LOG}
	else
		deploy_hpo ${cluster_type} ${HPO_CONTAINER_IMAGE} ${SERV_LOG}
	fi
	
	# Check if HPO services are started
	check_server_status

	for post_test in "${exp_tests[@]}"
	do

		# Get the length of the service log before the test
		log_length_before_test=$(cat ${SERV_LOG} | wc -l)

		TESTS_="${TEST_DIR}/${post_test}"
		mkdir -p ${TESTS_}
		LOG_="${TEST_DIR}/${post_test}.log"
		TEST_SERV_LOG="${TESTS_}/service.log"

		echo "************************************* ${post_test} Test ****************************************" | tee -a ${LOG_} ${LOG}
		echo "" | tee -a ${LOG_} ${LOG}

		exp="${post_test}"	

		experiment_name=""
		# Get the experiment id from search space JSON
		experiment_name=$(echo ${hpo_post_experiment_json[${post_test}]} | jq '.search_space.experiment_name')
		# Post the experiment JSON to HPO /experiment_trials API
		post_experiment_json "${hpo_post_experiment_json[$post_test]}"

		expected_log_msg="${hpo_error_messages[$post_test]}"
		
		post_exp_http_code="${http_code}"

		if [[ "${post_test}" == valid* ]]; then
			expected_result_="200"
		else
			expected_result_="400"
			if [[ "${post_test}" == "generate-subsequent" ]]; then
				expected_result_="404"
			fi
		fi

		actual_result="${http_code}"

		should_stop_expriment=false
		if [[ "${actual_result}" -eq "200" ]]; then
			should_stop_expriment=true
		fi

		# Extract the lines from the service log after log_length_before_test
		extract_lines=`expr ${log_length_before_test} + 1`
		cat ${SERV_LOG} | tail -n +${extract_lines} > ${TEST_SERV_LOG}
		
		echo ""
		echo "log_length_before_test ${log_length_before_test}"
		echo "extract_lines ${extract_lines}"
		echo ""

		echo ""
		if [[ "${http_code}" -eq "000" ]]; then
			failed=1
			((TOTAL_TESTS++))
			((TESTS++))
			error_message "${failed}" "${post_test}"
		else
			echo "actual_result = $actual_result expected_result = ${expected_result_}"
			compare_result "${post_test}" "${expected_result_}" "${expected_log_msg}" "${TEST_SERV_LOG}"
		fi

		echo ""

		if [ "$should_stop_expriment" == true ]; then
			stop_experiment "$experiment_name"
		fi

		echo "" | tee -a ${LOG_} ${LOG}
		
	done
	
	# Stop the HPO servers
	echo "Terminating any running HPO servers..." | tee -a ${LOG}
	terminate_hpo ${cluster_type}
	echo "Terminating any running HPO servers...Done" | tee -a ${LOG}

	echo "*********************************************************************************************************" | tee -a ${LOG_} ${LOG}
}

# Do a post on experiment_trials for the same experiment id again with "operation: EXP_TRIAL_GENERATE_NEW" and check if experiments have started from the beginning
function post_duplicate_experiments() {
	# Get the length of the service log before the test
	log_length_before_test=$(cat ${SERV_LOG} | wc -l)

	experiment_name=$(echo ${hpo_post_experiment_json[${exp}]} | jq '.search_space.experiment_name')
	post_experiment_json "${hpo_post_experiment_json[$exp]}"

	if [ "${http_code}" == "200" ]; then
		failed=0

		# Post the json with same Id having "operation: EXP_TRIAL_GENERATE_NEW"
		echo "Post the json with same Id having operation: EXP_TRIAL_GENERATE_NEW" | tee -a ${LOG_} ${LOG}

		echo ""
		post_experiment_json "${hpo_post_experiment_json[$exp]}"

		actual_result="${http_code}"
		expected_result_="400"
		expected_behaviour="Experiment already exists"

		# Extract the lines from the service log after log_length_before_test
		extract_lines=`expr ${log_length_before_test} + 1`
		cat ${SERV_LOG} | tail -n +${extract_lines} > ${TEST_SERV_LOG}

		compare_result "${FUNCNAME}" "${expected_result_}" "${expected_behaviour}" "${TEST_SERV_LOG}"
      		stop_experiment "$experiment_name"
	else
		failed=1
		expected_behaviour="RESPONSE_CODE = 200 OK"
		echo "Posting valid experiment failed"
		display_result "${expected_behaviour}" "${FUNCNAME}" "${failed}"
	fi
}

# Do a post on experiment_trials for the same experiment id again with "operation: EXP_TRIAL_GENERATE_SUBSEQUENT" and check if same experiment continues
function operation_generate_subsequent() {
	current_id=$(echo ${hpo_post_experiment_json[${exp}]} | jq '.search_space.experiment_id')
	current_name=$(echo ${hpo_post_experiment_json[${exp}]} | jq '.search_space.experiment_name')

	post_experiment_json "${hpo_post_experiment_json[$exp]}"
	trial_num="${response}"

	# Post a valid experiment result to HPO /experiment_trials API.
	echo -n "Post a valid experiment result to HPO..." | tee -a ${LOG_} ${LOG}
	experiment_result="valid-experiment-result"

	post_experiment_result_json "${hpo_post_exp_result_json[$experiment_result]}"

	# Post the json with same Id having "operation: EXP_TRIAL_GENERATE_SUBSEQUENT"
	echo "Post the json with same Id having operation: EXP_TRIAL_GENERATE_SUBSEQUENT" | tee -a ${LOG_} ${LOG}
	exp="generate-subsequent"
	post_experiment_json "${hpo_post_experiment_json[$exp]}"

	actual_result="${response}"
	expected_result_=$(($trial_num+1))
	expected_behaviour="Response is ${expected_result_}"

	compare_result "${FUNCNAME}" "${expected_result_}" "${expected_behaviour}" "${LOG_}"
}

# The test does the following: 
# * Post the same experiment again with operation set to "EXP_TRIAL_GENERATE_NEW" and validate the result.
# * Post the same experiment again with the operation set to "EXP_TRIAL_GENERATE_SUBSEQUENT" after we post the result for the previous trial, and check if subsequent trial number is generated
# input: Test name
function other_post_experiment_tests() {
	exp="valid-experiment"

	SERV_LOG="${TEST_DIR}/other_post_exps_service.log"
	# Deploy hpo
	if [ ${cluster_type} == "native" ]; then
		deploy_hpo ${cluster_type} ${SERV_LOG}
	else
		deploy_hpo ${cluster_type} ${HPO_CONTAINER_IMAGE} ${SERV_LOG}
	fi
	
	# Check if HPO services are started
	check_server_status

	for operation in "${other_post_experiment_tests[@]}"
	do

		TESTS_="${TEST_DIR}/${operation}"
		mkdir -p ${TESTS_}
		TEST_SERV_LOG="${TESTS_}/service.log"
		LOG_="${TEST_DIR}/${operation}.log"

		echo ""
		echo "************************************* ${operation} Test ****************************************" | tee -a ${LOG_} ${LOG}

		operation=$(echo ${operation//-/_})
		${operation}
		echo ""
	done
	
	# Stop the HPO servers
	echo "Terminating any running HPO servers..." | tee -a ${LOG}
	terminate_hpo ${cluster_type}
	echo "Terminating any running HPO servers...Done" | tee -a ${LOG}
	
	# Sleep for few seconds to reduce the ambiguity
	sleep 5

	echo "*********************************************************************************************************" | tee -a ${LOG_} ${LOG}
}

# Tests for HPO /experiment_trials API POST experiment
function hpo_post_experiment() {
	run_post_tests ${FUNCNAME}
	other_post_experiment_tests
}
