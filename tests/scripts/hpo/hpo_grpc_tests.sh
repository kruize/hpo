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

	echo "Wait for HPO service to come up"
	sleep 10

	pwd

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

		# Get the config from HPO
		sleep 2
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

		sleep 5

		# Generate a subsequent trial
		if [[ ${i} < $((N_TRIALS-1)) ]]; then
			echo "" | tee -a ${LOG}
		        echo "Generate subsequent config after trial ${i} ..." | tee -a ${LOG}
			python ../src/grpc_client.py next --name ${exp_name}
			verify_grpc_result "Post subsequent experiment after trial ${i}" $?
		fi
	done

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

	sleep 10

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
			expected_json="${TEST_DIR}/expected_hpo_config_exp${i}_trial${trial_num}.json"
		
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
