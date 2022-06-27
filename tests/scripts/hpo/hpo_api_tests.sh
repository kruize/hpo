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

# Get the absolute path of current directory
CURRENT_DIR="$(dirname "$(realpath "$0")")"
SCRIPTS_DIR="${CURRENT_DIR}/hpo"

# Source the common functions scripts
. ${SCRIPTS_DIR}/constants/hpo_api_constants.sh

hpo_option=""

export hpo_base_url=http://localhost:8085

# Tests to validate the HPO APIs
function hpo_api_tests() {
	start_time=$(get_date)
	FAILED_CASES=()
	TESTS_FAILED=0
	TESTS_PASSED=0
	TESTS=0
	((TOTAL_TEST_SUITES++))

	hpo_api_tests=("hpo_post_experiment"  "hpo_get_trial_json" "hpo_post_exp_result" "hpo_sanity_test" "hpo_grpc_sanity_test")

	# check if the test case is supported
	if [ ! -z "${testcase}" ]; then
		check_test_case "hpo_api"
	fi

	# create the result directory for given testsuite
	echo ""
	TEST_SUITE_DIR="${RESULTS_DIR}/hpo_api_tests"
	mkdir -p ${TEST_SUITE_DIR}

	# If testcase is not specified run all tests	
	if [ -z "${testcase}" ]; then
		testtorun=("${hpo_api_tests[@]}")
	else
		testtorun=${testcase}
	fi

	# Stop the HPO servers
	echo "Terminating any running HPO servers..."
	terminate_hpo ${cluster_type} > /dev/null
	echo "Terminating any running HPO servers...Done"

	# Sleep for few seconds to reduce the ambiguity
	sleep 2

	for test in "${testtorun[@]}"
	do
		TEST_DIR="${TEST_SUITE_DIR}/${test}"
		mkdir ${TEST_DIR}
		SETUP="${TEST_DIR}/setup.log"
		LOG="${TEST_SUITE_DIR}/${test}.log"

		echo ""
		echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" | tee -a ${LOG}
		echo "                    Running Test ${test}" | tee -a ${LOG}
		echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"| tee -a ${LOG}

		echo " " | tee -a ${LOG}
		echo "Test description: ${hpo_api_test_description[$test]}" | tee -a ${LOG}
		echo " " | tee -a ${LOG}

		# Perform the test
		${test}
	done

	if [ "${TESTS_FAILED}" -ne "0" ]; then
		FAILED_TEST_SUITE+=(${FUNCNAME})
	fi

	end_time=$(get_date)
	elapsed_time=$(time_diff "${start_time}" "${end_time}")

	# Remove the duplicates 
	FAILED_CASES=( $(printf '%s\n' "${FAILED_CASES[@]}" | uniq ) )

	# print the testsuite summary
	testsuitesummary ${FUNCNAME} ${elapsed_time} ${FAILED_CASES} 
}

function form_hpo_api_url {
	API=$1
	# Form the URL command based on the cluster type
	case $cluster_type in
		native|docker) 
			PORT="8085"
			SERVER_IP="localhost"
			URL="http://${SERVER_IP}"
			;;
		*);;
	esac

	# Add conditions later for other cluster types
	if [[ ${cluster_type} == "native" || ${cluster_type} == "docker" ]]; then
		hpo_url="${URL}:${PORT}/${API}"
	fi
}

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

# Post a JSON object to HPO(Hyper Parameter Optimization) module
# input: JSON object
# output: Create the Curl command with given JSON and get the result
function stop_experiment() {
	exp_name=$1
	echo ""
	echo "******************************************"
	echo "stop experiment = ${exp_name}"
	echo "******************************************"

	form_hpo_api_url "experiment_trials"

	remove_experiment='{"experiment_name":'${exp_name}',"operation":"EXP_STOP"}'

	post_cmd=$(curl -s -H 'Content-Type: application/json' ${hpo_url}  -d "${remove_experiment}"  -w '\n%{http_code}' 2>&1)

	stop_experiment_cmd="curl -s -H 'Content-Type: application/json' ${hpo_url} -d '${remove_experiment}'  -w '\n%{http_code}'"

	echo "" | tee -a ${LOG_} ${LOG}
	echo "Curl command used to stop the experiment = ${stop_experiment_cmd}" | tee -a ${LOG_} ${LOG}
	echo "" | tee -a ${LOG_} ${LOG}

	echo "${post_cmd}" >> ${LOG_} ${LOG}

	http_code=$(tail -n1 <<< "${post_cmd}")
	response=$(echo -e "${post_cmd}" | tail -2 | head -1)

	echo "Response is ${response}" >> ${LOG_} ${LOG}
	echo "http_code is $http_code Response is ${response}"
}

# Check if the servers have started
function check_server_status() {
  echo "Wait for HPO service to come up"
  #if service does not start within 5 minutes (300s) fail the test
  timeout 300 bash -c 'while [[ "$(curl -s -o /dev/null -w ''%{http_code}'' http://localhost:8085)" != "200" ]]; do sleep 1; done' || false


	service_log_msg="Access server at"

	if grep -q "${service_log_msg}" "${TEST_DIR}/service.log" ; then
		echo "HPO REST API service started successfully..." | tee -a ${LOG_} ${LOG}
	else
		echo "Error Starting the HPO REST API service..." | tee -a ${LOG_} ${LOG}
		echo "See ${TEST_DIR}/service.log for more details" | tee -a ${LOG_} ${LOG}
		cat "${TEST_DIR}/service.log"
		exit 1
	fi

	grpc_service_log_msg="Starting gRPC server at"
	if grep -q "${grpc_service_log_msg}" "${TEST_DIR}/service.log" ; then
		echo "HPO GRPC API service started successfully..." | tee -a ${LOG_} ${LOG}
	else
		echo "Error Starting the HPO GRPC API service..." | tee -a ${LOG_} ${LOG}
		echo "See TEST_DIR{TEST_DIR}/service.log for more details" | tee -a ${LOG_} ${LOG}
		cat "${TESTS_}/service.log"
		exit 1
	fi
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

			post_exp_http_code="${http_code}"

			# Post the experiment result to HPO /experiment_trials API
			post_experiment_result_json "${hpo_post_exp_result_json[$post_test]}"
			expected_log_msg="${hpo_exp_result_error_messages[$post_test]}"
		else
			# Get the experiment id from search space JSON
			experiment_name=$(echo ${hpo_post_experiment_json[${post_test}]} | jq '.search_space.experiment_name')
			# Post the experiment JSON to HPO /experiment_trials API
			post_experiment_json "${hpo_post_experiment_json[$post_test]}"

			expected_log_msg="${hpo_error_messages[$post_test]}"

			post_exp_http_code="${http_code}"
		fi

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
		if [[ "${post_exp_http_code}" -eq "200" ]]; then
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

		sleep 10
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
		# Get the length of the service log before the test
		log_length_before_test=$(cat ${SERV_LOG} | wc -l)

		TESTS_="${TEST_DIR}/${operation}"
		mkdir -p ${TESTS_}
		TEST_SERV_LOG="${TESTS_}/service.log"
		LOG_="${TEST_DIR}/${operation}.log"

		echo ""
		echo "************************************* ${operation} Test ****************************************" | tee -a ${LOG_} ${LOG}

		operation=$(echo ${operation//-/_})
		${operation}
		echo ""

		# Extract the lines from the service log after log_length_before_test
		extract_lines=`expr ${log_length_before_test} + 1`
		cat ${SERV_LOG} | tail -n +${extract_lines} > ${TEST_SERV_LOG}
	done
	
	# Stop the HPO servers
	echo "Terminating any running HPO servers..." | tee -a ${LOG}
	terminate_hpo ${cluster_type}
	echo "Terminating any running HPO servers...Done" | tee -a ${LOG}
	
	# Sleep for few seconds to reduce the ambiguity
	sleep 5

	echo "*********************************************************************************************************" | tee -a ${LOG_} ${LOG}
}

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
		# Get the length of the service log before the test
		log_length_before_test=$(cat ${SERV_LOG} | wc -l)

		TESTS_="${TEST_DIR}/${exp_trial}"
		mkdir -p ${TESTS_}
		LOG_="${TEST_DIR}/${exp_trial}.log"
		result="${TESTS_}/${exp_trial}_result.log"

		TEST_SERV_LOG="${TEST_}/service.log"
		echo "********** TEST_SERV_LOG = $TEST_SERV_LOG"

		echo "************************************* ${exp_trial} Test ****************************************" | tee -a ${LOG_} ${LOG}

		# Get the experiment id from search space JSON
		exp="valid-experiment"
		current_id=$(echo ${hpo_post_experiment_json[${exp}]} | jq '.search_space.experiment_id')
		current_name=$(echo ${hpo_post_experiment_json[${exp}]} | jq '.search_space.experiment_name')

		# Post a valid experiment to RM-HPO /experiment_trials API.
		post_experiment_json "${hpo_post_experiment_json[$exp]}"

		run_get_trial_json_test ${exp_trial}


		# Extract the lines from the service log after log_length_before_test
		extract_lines=`expr ${log_length_before_test} + 1`
		cat ${SERV_LOG} | tail -n +${extract_lines} > ${TEST_SERV_LOG}
		
		echo ""
		echo "log_length_before_test ${log_length_before_test}"
		echo "extract_lines ${extract_lines}"
		echo ""

		actual_result="${http_code}"

		expected_result_="^4[0-9][0-9]"
		expected_behaviour="RESPONSE_CODE = 4XX BAD REQUEST"

		echo "actual_result = $actual_result"
		compare_result ${exp_trial} ${expected_result_} "${expected_behaviour}" "${TEST_SERV_LOG}"
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

# Validate the trial json returned by RM-HPO GET operation
function validate_exp_trial() {
	service=$1
	tunable_count=0
	# Sort the actual json based on tunable name
	echo ""

	if [ "${service}" == "rest" ]; then
		echo "$(cat ${result} | jq  'sort_by(.tunable_name)')" > ${result}
		# Sort the json based on tunable name
		SEARCH_SPACE_JSON="/tmp/search_space.json"
		echo "${hpo_post_experiment_json["valid-experiment"]}" > ${SEARCH_SPACE_JSON}
		cat ${SEARCH_SPACE_JSON}
		echo "$(jq '[.search_space.tunables[] | {lower_bound: .lower_bound, name: .name, upper_bound: .upper_bound}] | sort_by(.name)' ${SEARCH_SPACE_JSON})" > ${expected_json}
	else
		echo "$(cat ${result} | jq '.config' | jq  'sort_by(.name)')" > ${result}
		EXP_JSON="./resources/searchspace_jsons/newExperiment.json"
		echo "$(jq '[.tuneables[] | {lower_bound: .lower_bound, name: .name, upper_bound: .upper_bound}] | sort_by(.name)' ${EXP_JSON})" > ${expected_json}
	fi


	echo "Actual tunables json"
	cat ${result}
	echo ""

	echo "Expected tunables json"
	cat ${expected_json}

	expected_tunables_len=$(cat ${expected_json} | jq '. | length')
	actual_tunables_len=$(cat ${result}  | jq '. | length')

	echo "___________________________________ Validate experiment trial __________________________________________" | tee -a ${LOG_} ${LOG}
	echo "" | tee -a ${LOG_} ${LOG}
	echo "expected tunables length = ${expected_tunables_len} actual tunables length = ${actual_tunables_len}"
	if [ "${expected_tunables_len}" -ne "${actual_tunables_len}" ]; then
		failed=1
		echo "Error - Number of expected and actual tunables should be same" | tee -a ${LOG_} ${LOG}

		echo "" | tee -a ${LOG_} ${LOG}
		echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" | tee -a ${LOG_} ${LOG}
	else
		echo "" | tee -a ${LOG_} ${LOG}
		echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" | tee -a ${LOG_} ${LOG}

		while [ "${tunable_count}" -lt "${expected_tunables_len}" ]
		do
			upperbound=$(cat ${expected_json} | jq '.['${tunable_count}'].upper_bound')
			lowerbound=$(cat ${expected_json} | jq '.['${tunable_count}'].lower_bound')
			tunable_name=$(cat ${expected_json} | jq '.['${tunable_count}'].name')
			if [ "${service}" == "rest" ]; then
				actual_tunable_name=$(cat ${result} | jq '.['${tunable_count}'].tunable_name')
				actual_tunable_value=$(cat ${result} | jq '.['${tunable_count}'].tunable_value')
			else
				actual_tunable_name=$(cat ${result} | jq '.['${tunable_count}'].name')
				actual_tunable_value=$(cat ${result} | jq '.['${tunable_count}'].value')
			fi

			# validate the tunable name
			echo "" | tee -a ${LOG_} ${LOG}
			echo "Validating the tunable name ${actual_tunable_name}..." | tee -a ${LOG_} ${LOG}
			if [ "${actual_tunable_name}" != "${tunable_name}" ]; then
				failed=1
				echo "Error - Actual Tunable name should match with the tunable name returned by dependency analyzer" | tee -a ${LOG_} ${LOG}
			fi
			echo "" | tee -a ${LOG_} ${LOG}

			echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" | tee -a ${LOG_} ${LOG}
			echo "" | tee -a ${LOG_} ${LOG}

			# validate the tunable value
			echo "Validating the tunable value for ${actual_tunable_name}..." | tee -a ${LOG_} ${LOG}

			if [[ $(bc <<< "${actual_tunable_value} >= ${lowerbound} && ${actual_tunable_value} <= ${upperbound}") == 0 ]]; then
				failed=1
				echo "Error - Actual Tunable value should be within the given range" | tee -a ${LOG_} ${LOG}
			fi
			echo "" | tee -a ${LOG_} ${LOG}
			echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" | tee -a ${LOG_} ${LOG}
			((tunable_count++))
		done
	fi
	echo ""
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
		expected_result_="400"
		expected_behaviour="Requested trial exceeds the completed trial limit"

		sleep 20
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

# Tests for HPO /experiment_trials API POST experiment
function hpo_post_experiment() {
	run_post_tests ${FUNCNAME}
	other_post_experiment_tests
}

# Tests for RM-HPO GET trial JSON API
function hpo_get_trial_json(){
	for test in "${!hpo_get_trial_json_tests[@]}"
	do
		${test} "${FUNCNAME}"
	done 
}

# Tests for HPO /experiment_trials API POST experiment results
function hpo_post_exp_result() {
	run_post_tests ${FUNCNAME}
	other_exp_result_post_tests
}

# Sanity Test for HPO gRPC service
function hpo_grpc_sanity_test() {
	((TOTAL_TESTS++))
	((TESTS++))

	# Set the no. of trials
	N_TRIALS=5
	failed=0
	EXP_JSON="./resources/searchspace_jsons/newExperiment.json"

	# Get the experiment name from the search space
	exp_name=$(cat ${EXP_JSON}  | jq '.experiment_name')
	exp_name=$(echo ${exp_name} | sed 's/^"\(.*\)"$/\1/')
	echo "Experiment name = $exp_name"

	TESTS_=${TEST_DIR}
	SERV_LOG="${TESTS_}/service.log"
	echo "RESULTSDIR - ${TEST_DIR}" | tee -a ${LOG}
	echo "" | tee -a ${LOG}

	# Deploy hpo
	if [ ${cluster_type} == "native" ]; then
		deploy_hpo ${cluster_type} ${SERV_LOG}
	else
		deploy_hpo ${cluster_type} ${HPO_CONTAINER_IMAGE} ${SERV_LOG}
	fi

	# Check if HPO services are started
	check_server_status

	## Loop through the trials
	for (( i=0 ; i<${N_TRIALS} ; i++ ))
	do
		echo ""
		echo "*********************************** Trial ${i} *************************************"
		LOG_="${TEST_DIR}/hpo-trial-${i}.log"
		if [ ${i} == 0 ]; then
			echo "Posting a new experiment..."
			python ../src/grpc_client.py new --file="${EXP_JSON}"
			verify_grpc_result "Post new experiment" $?
		fi

		echo ""
		echo "Generate the config for trial ${i}..." | tee -a ${LOG}
		echo ""
		result="${TEST_DIR}/hpo_config_${i}.json"
		expected_json="${TEST_DIR}/expected_hpo_config_${i}.json"

		python ../src/grpc_client.py config --name ${exp_name} --trial ${i} > ${result}
		verify_grpc_result "Get config from hpo for trial ${i}" $?

		# Post the experiment result to hpo
		echo "" | tee -a ${LOG}
		echo "Post the experiment result for trial ${i}..." | tee -a ${LOG}
		result_value="98.7"

		python ../src/grpc_client.py result --name "${exp_name}" --trial "${i}" --result SUCCESS --value_type "double" --value "${result_value}"
		verify_grpc_result "Post new experiment result for trial ${i}" $?

		# Generate a subsequent trial
		if [[ ${i} < $((N_TRIALS-1)) ]]; then
			echo "" | tee -a ${LOG}
		        echo "Generate subsequent config after trial ${i} ..." | tee -a ${LOG}
			python ../src/grpc_client.py next --name ${exp_name}
			verify_grpc_result "Post subsequent experiment after trial ${i}" $?
		fi
	done

  #Validate removing test
  python ../src/grpc_client.py stop --name ${exp_name}
  verify_grpc_result "Stop running experiment ${exp_name}" $?

	# Terminate any running HPO servers
	echo "Terminating any running HPO servers..." | tee -a ${LOG}
	terminate_hpo ${cluster_type}
	echo "Terminating any running HPO servers...Done" | tee -a ${LOG}
	sleep 2

	# check for failed cases
	if [[ ${failed} == 0 ]]; then
		((TESTS_PASSED++))
		((TOTAL_TESTS_PASSED++))
		echo "Test Passed" | tee -a ${LOG}
	else
		((TESTS_FAILED++))
		((TOTAL_TESTS_FAILED++))
		FAILED_CASES+=(${testcase})
		echo "Check the logs for error messages : ${TEST_DIR}"| tee -a ${LOG}
		echo "Test failed" | tee -a ${LOG}
	fi
}

function verify_grpc_result() {
	test_info=$1
	exit_code=$2

	if [ ${exit_code} -ne 0 ]; then
		failed=1
		echo "$test_info failed!"
	else
		if [[ "${test_info}" =~ "Get config" ]]; then
			validate_exp_trial "grpc"
			if [[ ${failed} == 1 ]]; then
				echo "Validating hpo config failed" | tee -a ${LOG}
			fi
		fi
	fi
}

# Sanity Test for HPO REST service
function hpo_sanity_test() {
	((TOTAL_TESTS++))
	((TESTS++))

	# Set the no. of trials
	N_TRIALS=5
	failed=0

	# Form the url based on cluster type & API
	form_hpo_api_url "experiment_trials"
	echo "HPO URL = $hpo_url"  | tee -a ${LOG}

	# Get the experiment id and name from the search space
	exp_id=$(echo ${hpo_post_experiment_json["valid-experiment"]} | jq '.search_space.experiment_id')
	exp_name=$(echo ${hpo_post_experiment_json["valid-experiment"]} | jq '.search_space.experiment_name')
	echo "Experiment id = $exp_id"
	echo "Experiment name = $exp_name"

	TESTS_=${TEST_DIR}
	SERV_LOG="${TESTS_}/service.log"
	echo "RESULTSDIR - ${TEST_DIR}" | tee -a ${LOG}
	echo "" | tee -a ${LOG}

	# Deploy hpo
	if [ ${cluster_type} == "native" ]; then
		deploy_hpo ${cluster_type} ${SERV_LOG}
	else
		deploy_hpo ${cluster_type} ${HPO_CONTAINER_IMAGE} ${SERV_LOG}
	fi

	# Check if HPO services are started
	check_server_status

	expected_http_code="200"

	hostname=$(hostname)
	echo "hostname = $hostname "
	cat /etc/hosts
	echo ""

	## Loop through the trials
	for (( i=0 ; i<${N_TRIALS} ; i++ ))
	do
		echo ""
		echo "*********************************** Trial ${i} *************************************"
		LOG_="${TEST_DIR}/hpo-trial-${i}.log"
		if [ ${i} == 0 ]; then
			# Post the experiment
			echo "Start a new experiment with the search space json..." | tee -a ${LOG}
			post_experiment_json "${hpo_post_experiment_json["valid-experiment"]}"
			verify_result "Post new experiment" "${http_code}" "${expected_http_code}"
		fi

		# Get the config from HPO
		echo ""
		echo "Generate the config for trial ${i}..." | tee -a ${LOG}
		echo ""

		curl="curl -H 'Accept: application/json'"
		url="$hpo_base_url/experiment_trials"

		get_trial_json=$(${curl} ''${hpo_url}'?experiment_name=petclinic-sample-2-75884c5549-npvgd&trial_number='${i}'' -w '\n%{http_code}' 2>&1)

		get_trial_json_cmd="${curl} ${url}?experiment_name="petclinic-sample-2-75884c5549-npvgd"&trial_number=${i} -w '\n%{http_code}'"
		echo "command used to query the experiment_trial API = ${get_trial_json_cmd}" | tee -a ${LOG}

		http_code=$(tail -n1 <<< "${get_trial_json}")
		response=$(echo -e "${get_trial_json}" | tail -2 | head -1)
		response=$(echo ${response} | cut -c 4-)

		result="${TEST_DIR}/hpo_config_${i}.json"
		expected_json="${TEST_DIR}/expected_hpo_config_${i}.json"

		echo "${response}" > ${result}
		cat $result
		verify_result "Get config from hpo trial ${i}" "${http_code}" "${expected_http_code}"

		# Post the experiment result to hpo
		echo "" | tee -a ${LOG}
		echo "Post the experiment result for trial ${i}..." | tee -a ${LOG}
		trial_result="success"
		result_value="98.7"
		exp_result_json='{"experiment_name":'${exp_name}',"trial_number":'${i}',"trial_result":"'${trial_result}'","result_value_type":"double","result_value":'${result_value}',"operation":"EXP_TRIAL_RESULT"}'
		post_experiment_result_json ${exp_result_json}
		verify_result "Post experiment result for trial ${i}" "${http_code}" "${expected_http_code}"

		# Generate a subsequent trial
		if [[ ${i} < $((N_TRIALS-1)) ]]; then
			echo "" | tee -a ${LOG}
			echo "Generate subsequent config after trial ${i} ..." | tee -a ${LOG}
			subsequent_trial='{"experiment_name":'${exp_name}',"operation":"EXP_TRIAL_GENERATE_SUBSEQUENT"}'
			post_experiment_json ${subsequent_trial}
			verify_result "Post subsequent experiment after trial ${i}" "${http_code}" "${expected_http_code}"
		fi
	done

  #Validate removing test
  stop_experiment='{"experiment_name":'${exp_name}',"operation":"EXP_STOP"}'
  post_experiment_json ${stop_experiment}
  verify_result "Stop running experiment ${exp_name}" "${http_code}" "200"

  #verify test has been remove

	# Store the docker logs
	if [ ${cluster_type} == "docker" ]; then
		docker logs hpo_docker_container > ${TEST_DIR}/hpo_container.log 2>&1
	fi

	# Terminate any running HPO servers
	echo "Terminating any running HPO servers..." | tee -a ${LOG}
	terminate_hpo ${cluster_type}
	echo "Terminating any running HPO servers...Done" | tee -a ${LOG}
	sleep 2

	# check for failed cases
	echo "failed = $failed"
	if [[ ${failed} == 0 ]]; then
		((TESTS_PASSED++))
		((TOTAL_TESTS_PASSED++))
		echo "Test Passed" | tee -a ${LOG}
	else
		((TESTS_FAILED++))
		((TOTAL_TESTS_FAILED++))
		FAILED_CASES+=(${testcase})
		echo "Check the logs for error messages : ${TEST_DIR}"| tee -a ${LOG}
		echo "Test failed" | tee -a ${LOG}
	fi
}

function verify_result() {
	test_info=$1
	http_code=$2
	expected_http_code=$3

	if [[ "${http_code}" -eq "000" ]]; then
		failed=1
	else
		if [[ ${http_code} -ne ${expected_http_code} ]]; then
			failed=1
			echo "${test_info} failed - http_code is not as expected, http_code = ${http_code} expected code = ${expected_http_code}" | tee -a ${LOG}
		else
			if [[ "${test_info}" =~ "Get config" ]]; then
				validate_exp_trial "rest"
				if [[ ${failed} == 1 ]]; then
					echo "Validating hpo config failed" | tee -a ${LOG}
				fi
			fi
		fi
	fi
}
