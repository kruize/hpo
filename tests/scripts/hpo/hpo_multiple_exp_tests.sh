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
##### Script for validating HPO (Hyper Parameter Optimization) with multiple experiments #####

# Multple experiments test for HPO REST service
function hpo_grpc_multiple_exp_test() {
	((TOTAL_TESTS++))
	((TESTS++))

	# Set the no. of experiments
	NUM_EXPS=5

	# Set the no. of trials
	N_TRIALS=3
	failed=0
	EXP_JSON="./resources/searchspace_jsons/newExperiment.json"

	# Form the url based on cluster type & API
	form_hpo_api_url "experiment_trials"
	echo "HPO URL = $hpo_url"  | tee -a ${LOG}


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
	check_server_status "${SERV_LOG}"

	expected_http_code="200"

	hostname=$(hostname)
	echo "hostname = $hostname "
	cat /etc/hosts
	echo ""

	exp_json=${hpo_post_experiment_json["valid-experiment"]}

	## Start multiple experiments
	for (( i=1 ; i<=${NUM_EXPS} ; i++ ))
	do
		LOG_="${TEST_DIR}/hpo-exp-${i}.log"
		# Post the experiment
		echo "Start a new experiment with the search space json..." | tee -a ${LOG}

		# Replace the experiment name
		cat $EXP_JSON | sed -e 's/petclinic-sample-2-75884c5549-npvgd/petclinic-sample-'${i}'/' > ${TEST_DIR}/petclinic-exp-${i}.json

		echo "Posting a new experiment..."
		python ../src/grpc_client.py new --file="${TEST_DIR}/petclinic-exp-${i}.json"
		verify_grpc_result "Post new experiment" $?

		sleep 5

	done

	## Loop through the trials
	for (( trial_num=0 ; trial_num<${N_TRIALS} ; trial_num++ ))
	do

		for (( i=1 ; i<=${NUM_EXPS} ; i++ ))
		do
			exp_name="petclinic-sample-${i}"
			echo ""
			echo "*********************************** Experiment ${exp_name} and trial_number ${trial_num} *************************************"
			LOG_="${TEST_DIR}/hpo-exp-${i}-trial-${trial_num}.log"

			# Get the config from HPO
			sleep 2
			echo ""
			echo "Generate the config for trial experiment ${exp_name} and ${trial_num}..." | tee -a ${LOG}
			echo ""
			result="${TEST_DIR}/hpo_config_exp${i}_trial${trial_num}.json"
			expected_json="${TEST_DIR}/expected_hpo_config_exp${i}.json"
		
			get_trial_json_cmd="python ../src/grpc_client.py config --name ${exp_name} --trial ${trial_num}"
			echo "command to query the experiment_trial API = ${get_trial_json_cmd}" | tee -a ${LOG}

			echo "result = $result  epxected_json = $expected_json"
			python ../src/grpc_client.py config --name ${exp_name} --trial ${trial_num} > ${result}
			verify_grpc_result "Get config from hpo for experiment ${exp_name} and trial ${trial_num}" $?


			# Post the experiment result to hpo
			echo "" | tee -a ${LOG}
			echo "Post the experiment result for trial ${trial_num}..." | tee -a ${LOG}
			result_value="198.7"

			if [[ ${trial_num} == 1 ]]; then
				echo "Posting a FAILURE result..."
				python ../src/grpc_client.py result --name "${exp_name}" --trial "${trial_num}" --result FAILURE --value_type "double" --value "${result_value}"
			else
				python ../src/grpc_client.py result --name "${exp_name}" --trial "${trial_num}" --result SUCCESS --value_type "double" --value "${result_value}"
			fi

			verify_grpc_result "Post new experiment result for experiment ${exp_name} and trial ${trial_num}" $?
	
			sleep 5

			# Generate a subsequent trial
			if [[ ${trial_num} < $((N_TRIALS-1)) ]]; then
				echo "" | tee -a ${LOG}
				echo "Generate subsequent config for experiment ${exp_name} after trial ${trial_num} ..." | tee -a ${LOG}
				python ../src/grpc_client.py next --name ${exp_name}
				verify_grpc_result "Post subsequent for experiment ${exp_name} after trial ${trial_num}" $?
			fi
		done
	done

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

# Multple experiments test for HPO REST service
function hpo_multiple_exp_test() {
	((TOTAL_TESTS++))
	((TESTS++))

	# Set the no. of experiments
	NUM_EXPS=5

	# Set the no. of trials
	N_TRIALS=3
	failed=0

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
	check_server_status "${SERV_LOG}"

	expected_http_code="200"

	hostname=$(hostname)
	echo "hostname = $hostname "
	cat /etc/hosts
	echo ""

	exp_json=${hpo_post_experiment_json["valid-experiment"]}

	## Start multiple experiments
	for (( i=1 ; i<=${NUM_EXPS} ; i++ ))
	do
		LOG_="${TEST_DIR}/hpo-exp-${i}.log"
		# Post the experiment
		echo "Start a new experiment with the search space json..." | tee -a ${LOG}

		# Replace the experiment name
		json=$(echo $exp_json | sed -e 's/petclinic-sample-2-75884c5549-npvgd/petclinic-sample-'${i}'/')
		post_experiment_json "$json"
		verify_result "Post new experiment" "${http_code}" "${expected_http_code}"

		sleep 5

	done

	## Loop through the trials
	for (( trial_num=0 ; trial_num<${N_TRIALS} ; trial_num++ ))
	do

		for (( i=1 ; i<=${NUM_EXPS} ; i++ ))
		do
			exp_name="petclinic-sample-${i}"
			echo ""
			echo "*********************************** Experiment ${exp_name} and trial_number ${trial_num} *************************************"
			LOG_="${TEST_DIR}/hpo-exp${i}-trial${trial_num}.log"

			# Get the config from HPO
			sleep 2
			echo ""
			echo "Generate the config for experiment ${i} and trial ${trial_num}..." | tee -a ${LOG}
			echo ""

			curl="curl -H 'Accept: application/json'"
			url="http://localhost:8085/experiment_trials"

			get_trial_json=$(${curl} ''${hpo_url}'?experiment_name='${exp_name}'&trial_number='${trial_num}'' -w '\n%{http_code}' 2>&1)

			get_trial_json_cmd="${curl} ${url}?experiment_name="${exp_name}"&trial_number=${trial_num} -w '\n%{http_code}'"
			echo "command used to query the experiment_trial API = ${get_trial_json_cmd}" | tee -a ${LOG}

			# check for curl '000' error
			curl_error_check

			result="${TEST_DIR}/hpo_config_exp${i}_trial${trial_num}.json"
			expected_json="${TEST_DIR}/expected_hpo_config_exp${i}.json"

			echo "${response}" > ${result}
			cat $result
			verify_result "Get config from hpo for experiment ${exp_name} and trial ${trial_num}" "${http_code}" "${expected_http_code}"

			# Added a sleep to mimic experiment run
			sleep 10 

			# Post the experiment result to hpo
			echo "" | tee -a ${LOG}
			echo "Post the experiment result for experiment ${exp_name} and trial ${trial_num}..." | tee -a ${LOG}
			trial_result="success"
			result_value="98.7"
			exp_result_json='{"experiment_name":"'${exp_name}'","trial_number":'${trial_num}',"trial_result":"'${trial_result}'","result_value_type":"double","result_value":'${result_value}',"operation":"EXP_TRIAL_RESULT"}'
			post_experiment_result_json ${exp_result_json}
			verify_result "Post experiment result for experiment ${exp_name} and trial ${trial_num}" "${http_code}" "${expected_http_code}"
	
			sleep 5

			# Generate a subsequent trial
			if [[ ${trial_num} < $((N_TRIALS-1)) ]]; then
				echo "" | tee -a ${LOG}
				echo "Generate subsequent config for experiment ${exp_name} after trial ${trial_num} ..." | tee -a ${LOG}
				subsequent_trial='{"experiment_name":"'${exp_name}'","operation":"EXP_TRIAL_GENERATE_SUBSEQUENT"}'
				post_experiment_json ${subsequent_trial}
				verify_result "Post subsequent for experiment ${exp_name} after trial ${trial_num}" "${http_code}" "${expected_http_code}"
			fi
		done
	done

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
