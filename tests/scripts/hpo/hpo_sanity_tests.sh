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

	# Check if HPO services are started
	check_server_status "${SERV_LOG}"

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

	# Validate removing test
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

# Sanity Test for HPO REST service
function hpo_sanity_test() {
	((TOTAL_TESTS++))
	((TESTS++))

	# Set the no. of trials
	N_TRIALS=5
	failed=0

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
	check_server_status "${SERV_LOG}"

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

		get_trial_json_cmd="${curl} ${hpo_url}?experiment_name="petclinic-sample-2-75884c5549-npvgd"&trial_number=${i} -w '\n%{http_code}'"
		echo "command used to query the experiment_trial API = ${get_trial_json_cmd}" | tee -a ${LOG}

		http_code=$(tail -n1 <<< "${get_trial_json}")
		response=$(echo -e "${get_trial_json}" | tail -2 | head -1)

		if [ ${response::3} == "000" ]; then
			response=$(echo ${response} | cut -c 4-)
		fi

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

	# Validate removing test
	stop_experiment='{"experiment_name":'${exp_name}',"operation":"EXP_STOP"}'
	post_experiment_json ${stop_experiment}
	verify_result "Stop running experiment ${exp_name}" "${http_code}" "200"
	
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

