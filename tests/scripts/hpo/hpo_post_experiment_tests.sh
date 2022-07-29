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

# Do a post on experiment_trials for the same experiment id again with "operation: EXP_TRIAL_GENERATE_NEW" and check if experiments have started from the beginning
function post_grpc_duplicate_experiments() {
	# Get the length of the service log before the test
	log_length_before_test=$(cat ${SERV_LOG} | wc -l)

	experiment_name=$(echo ${hpo_post_experiment_json[${exp}]} | jq '.search_space.experiment_name')
	post_grpc_experiment_json "${hpo_grpc_post_experiment_json[$exp]}"

	if [ "$?" == "0" ]; then
		# Post the same experiment again 
		echo "Posting the same experiment again" | tee -a ${LOG_} ${LOG}

		echo ""
		post_grpc_experiment_json "${hpo_grpc_post_experiment_json[$exp]}"
	else
		failed=1
		expected_behaviour="return code not equal to 0"
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
	service=$1
	exp="valid-experiment"

	SERV_LOG="${TEST_DIR}/other_post_exps_service.log"
	# Deploy hpo
	if [ ${cluster_type} == "native" ]; then
		deploy_hpo ${cluster_type} ${SERV_LOG}
	else
		deploy_hpo ${cluster_type} ${HPO_CONTAINER_IMAGE} ${SERV_LOG}
	fi
	
	# Check if HPO services are started
	check_server_status "${SERV_LOG}"

	if [ ${service} == "rest" ]; then
		tests_to_run=${other_post_experiment_tests[@]}
	else
		tests_to_run=${other_grpc_post_experiment_tests[@]}
	fi

	for operation in "${tests_to_run[@]}"
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

# Tests for GRPC HPO POST experiment
function hpo_grpc_post_experiment() {
	run_grpc_post_tests ${FUNCNAME}
	other_post_experiment_tests "grpc"
}

# Tests for HPO /experiment_trials API POST experiment
function hpo_post_experiment() {
	run_post_tests ${FUNCNAME}
	other_post_experiment_tests "rest"
}
