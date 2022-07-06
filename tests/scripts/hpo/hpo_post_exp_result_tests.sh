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
		if [ "${hpo_test_name}" == "hpo_post_exp_result" ]; then
			exp="valid-experiment"
			# Get the experiment id from search space JSON
			experiment_name=$(echo ${hpo_post_experiment_json[${exp}]} | jq '.search_space.experiment_name')
			# Post the experiment JSON to HPO /experiment_trials API
			post_experiment_json "${hpo_post_experiment_json[${exp}]}"

			# Post the experiment result to HPO /experiment_trials API
			post_experiment_result_json "${hpo_post_exp_result_json[$post_test]}"
			expected_log_msg="${hpo_exp_result_error_messages[$post_test]}"
		else
			# Get the experiment id from search space JSON
			experiment_name=$(echo ${hpo_post_experiment_json[${post_test}]} | jq '.search_space.experiment_name')
			# Post the experiment JSON to HPO /experiment_trials API
			post_experiment_json "${hpo_post_experiment_json[$post_test]}"
			expected_log_msg="${hpo_error_messages[$post_test]}"
		fi

		if [[ "${post_test}" == valid* ]]; then
			expected_result_="200"
			expected_behaviour="RESPONSE_CODE = 200 OK"
		else
			expected_result_="^4[0-9][0-9]"
			expected_behaviour="RESPONSE_CODE = 4XX BAD REQUEST"
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
			if [[ ! -z ${expected_log_msg} ]]; then
				if grep -q "${expected_log_msg}" "${TEST_SERV_LOG}" ; then
					failed=0 
				else
					failed=1
				fi
			else
				failed=1
			fi

			((TOTAL_TESTS++))
			((TESTS++))
			error_message "${failed}" "${post_test}"
		else
			echo "actual_result = $actual_result expected_result = ${expected_result_}"
			compare_result "${post_test}" "${expected_result_}" "${expected_behaviour}"
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
		expected_result_="^4[0-9][0-9]"
		expected_behaviour="RESPONSE_CODE = 4XX BAD REQUEST"

		compare_result "${FUNCNAME}" "${expected_result_}" "${expected_behaviour}"
	else
		failed=1
		expected_behaviour="RESPONSE_CODE = 200 OK"
		echo "Posting valid experiment failed"
		display_result "${expected_behaviour}" "${FUNCNAME}" "${failed}"
	fi
}

# Post different experiment results to HPO /experiment_trials API for the same experiment id and validate the result
function post_same_id_different_exp_result() {
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
		expected_result_="^4[0-9][0-9]"
		expected_behaviour="RESPONSE_CODE = 4XX BAD REQUEST"

		compare_result "${FUNCNAME}" "${expected_result_}" "${expected_behaviour}"
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
		# Get the length of the service log before the test
		log_length_before_test=$(cat ${SERV_LOG} | wc -l)

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

		# Extract the lines from the service log after log_length_before_test
		extract_lines=`expr ${log_length_before_test} + 1`
		cat ${SERV_LOG} | tail -n +${extract_lines} > ${TEST_SERV_LOG}

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

