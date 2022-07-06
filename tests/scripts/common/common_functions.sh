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
##### Common routines used in the tests #####
#

CURRENT_DIR="$(dirname "$(realpath "$0")")"
HPO_REPO="${CURRENT_DIR}/../.."

# variables to keep track of overall tests performed
TOTAL_TESTS_FAILED=0
TOTAL_TESTS_PASSED=0
TOTAL_TEST_SUITES=0
TOTAL_TESTS=0

# variables to keep track of tests performed for each test suite
TESTS_FAILED=0
TESTS_PASSED=0
TESTS=0

TEST_MODULE_ARRAY=("hpo")

TEST_SUITE_ARRAY=("hpo_api_tests")

total_time=0
matched=0
sanity=0
setup=1

# checks if the previous command is executed successfully
# input:Return value of previous command
# output:Prompts the error message if the return value is not zero 
function err_exit() {
	err=$?
	if [ ${err} -ne 0 ]; then
		echo "$*"
	fi
}

# Check if jq is installed
function check_prereq() {
	echo
	echo "Info: Checking prerequisites..."
	# check if jq exists
	if ! [ -x "$(command -v jq)" ]; then
		echo "Error: jq is not installed."
		exit 1
	fi
}

# get date in format
function get_date() {
	date "+%Y-%m-%d %H:%M:%S"
}

function time_diff() {
	ssec=`date --utc --date "$1" +%s`
	esec=`date --utc --date "$2" +%s`

	diffsec=$(($esec-$ssec))
	echo $diffsec
}

# Deploy hpo
# input: cluster type, hpo container image
# output: Deploy hpo based on the parameter passed
function deploy_hpo() {
	cluster_type=$1
	HPO_CONTAINER_IMAGE=$2

	pushd ${HPO_REPO} > /dev/null
	
	if [ ${cluster_type} == "native" ]; then
		echo
		echo
		log=$2
		cmd="./deploy_hpo.sh -c ${cluster_type} > ${log} 2>&1 &"
		echo "Command to deploy hpo - ${cmd}"
		./deploy_hpo.sh -c ${cluster_type} > ${log} 2>&1 &
	else 
		cmd="./deploy_hpo.sh -c ${cluster_type} -o ${HPO_CONTAINER_IMAGE}"
		echo "Command to deploy hpo - ${cmd}"
		./deploy_hpo.sh -c ${cluster_type} -o ${HPO_CONTAINER_IMAGE}
	fi
	
	status="$?"
	# Check if hpo is deployed.
	if [[ "${status}" -eq "1" ]]; then
		echo "Error deploying hpo" >>/dev/stderr
		exit -1
	fi

	if [ ${cluster_type} == "docker" ]; then
  	sleep 2
		log=$3
		docker logs hpo_docker_container > "${log}" 2>&1
	fi

	popd > /dev/null
	echo "Deploying HPO as a service...Done"
}

# Remove the hpo setup
function terminate_hpo() {
	cluster_type=$1

	pushd ${HPO_REPO} > /dev/null
		echo  "Terminating hpo..."
		cmd="./deploy_hpo.sh -c ${cluster_type} -t"
		echo "CMD = ${cmd}"
		./deploy_hpo.sh -c ${cluster_type} -t
	popd > /dev/null
	echo "done"
}

# list of test cases supported 
# input: testsuite
# ouput: print the testcases supported for specified testsuite
function test_case_usage() {
	checkfor=$1
	typeset -n hpo_tests="${checkfor}_tests"
	echo
	echo "Supported Test cases are:"
	for tests in "${hpo_tests[@]}"
	do
		echo "		           ${tests}"
	done
}

# Check if the given test case is supported 
# input: testsuite
# output: check if the specified testcase is supported if not then call test_case_usage
function check_test_case() {
	checkfor=$1
	typeset -n hpo_tests=${checkfor}_tests
	for test in ${hpo_tests[@]}
	do
		if [ "${testcase}" == "${test}" ]; then
			testcase_matched=1
		fi
	done
	
	if [ "${testcase}" == "help" ]; then
		test_case_usage ${checkfor}
		exit -1
	fi
	
	if [[ "${testcase_matched}" -eq "0" ]]; then
		echo ""
		echo "Error: Invalid testcase **${testcase}** "
		test_case_usage ${checkfor}
		exit -1
	fi
}

# get the summary of each test suite
# input: Test suite name for which you want to get the summary and the failed test cases 
# output: summary of the specified test suite
function testsuitesummary() {
	TEST_SUITE_NAME=$1
	elapsed_time=$2
	FAILED_CASES=$3
	((total_time=total_time+elapsed_time))
	echo 
	echo "########### Results Summary of the test suite ${TEST_SUITE_NAME} ##########"
	echo "${TEST_SUITE_NAME} took ${elapsed_time} seconds"
	echo "Number of tests performed ${TESTS}"
	echo "Number of tests passed ${TESTS_PASSED}"
	echo "Number of tests failed ${TESTS_FAILED}"
	echo ""
	if [ "${TESTS_FAILED}" -ne "0" ]; then
		echo "~~~~~~~~~~~~~~~~~~~~~~~ ${TEST_SUITE_NAME} failed ~~~~~~~~~~~~~~~~~~~~~~~~~~"
		echo "Failed cases are :"
		for fails in "${FAILED_CASES[@]}"
		do
			echo "		  ${fails}"
		done
		echo
		echo "Check Log Directory: ${TEST_SUITE_DIR} for failed cases "
		echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
	else 
		echo "~~~~~~~~~~~~~~~~~~~~~~ ${TEST_SUITE_NAME} passed ~~~~~~~~~~~~~~~~~~~~~~~~~~"
	fi
	echo ""
	echo "************************************** done *************************************"
}

# get the overall summary of the test
# input: failed test suites 
# output: summary of the overall tests performed
function overallsummary(){
	FAILED_TEST_SUITES=$1
	echo "Total time taken to perform the test ${total_time} seconds"
	echo "Total Number of test suites performed ${TOTAL_TEST_SUITES}"
	echo "Total Number of tests performed ${TOTAL_TESTS}"
	echo "Total Number of tests passed ${TOTAL_TESTS_PASSED}"
	echo "Total Number of tests failed ${TOTAL_TESTS_FAILED}"
	if [ "${TOTAL_TESTS_FAILED}" -ne "0" ]; then
		echo ""
		echo "Check below testsuite logs for failed test cases:"
		for fails in "${FAILED_TEST_SUITE[@]}"
		do
			echo "		                        ${fails}"
		done
	fi
}

# print the message for the test
# input: status
# ouput: based on the status passed print the messages
function error_message() {
	failed=$1
	test_name=$2

	echo ""
	# check for failed cases
	if [ "${failed}" -eq "0" ]; then
		((TESTS_PASSED++))
		((TOTAL_TESTS_PASSED++))
		echo "Expected message is : ${expected_log_msg}"| tee -a ${LOG}
		echo "Expected message found in the log"
		echo "Test Passed" | tee -a ${LOG}
	else
		((TESTS_FAILED++))
		((TOTAL_TESTS_FAILED++))
		FAILED_CASES+=(${test_name})
		echo "Expected message is : ${expected_log_msg}"| tee -a ${LOG}
		echo "Expected message not found"
		echo "Test failed" | tee -a ${LOG}
	fi
}

# Compare the actual json and expected jsons
# Input: Acutal json, expected json
function compare_json() {
	((TESTS++))
	((TOTAL_TESTS++))
	actual_json=$1
	expected_json=$2
	testcase=$3

	compared=$(jq --argfile actual ${actual_json} --argfile expected ${expected_json} -n '($actual | (.. | arrays) |= sort) as $actual | ($expected | (.. | arrays) |= sort) as $expected | $actual == $expected')
	if [ "${compared}" == "true" ]; then
		echo "Expected json matched with the actual json" | tee -a ${LOG}
		echo "Test passed" | tee -a ${LOG}
		((TESTS_PASSED++))
		((TOTAL_TESTS_PASSED++))
	else
		echo "Expected json did not match with the actual json" | tee -a ${LOG}
		echo "Test failed" | tee -a ${LOG}
		((TESTS_FAILED++))
		((TOTAL_TESTS_FAILED++))
		FAILED_CASES+=(${testcase})
	fi
}

# Run the curl command passed and capture the json output in a file
# Input: curl command, json file name
function run_curl_cmd() {
	cmd=$1
	json_file=$2
 
	echo "Curl cmd=${cmd}" | tee -a ${LOG}
	echo "json file = ${json_file}" | tee -a ${LOG}
	${cmd} > ${json_file}
	echo "actual json" >> ${LOG}
	cat ${json_file} >> ${LOG}
	echo "" >> ${LOG}
}

# Display the result based on the actual flag value
# input: Expected behaviour, test name and actual flag value
function display_result() {
	expected_behaviour=$1
	_id_test_name_=$2
	actual_flag=$3
	((TOTAL_TESTS++))
	((TESTS++))
	echo "Expected behaviour: ${expected_behaviour}" | tee -a ${LOG}
	if [ "${actual_flag}" -eq "0" ]; then
		((TESTS_PASSED++))
		((TOTAL_TESTS_PASSED++))
		echo "Expected behaviour found" | tee -a ${LOG}
		echo "Test passed" | tee -a ${LOG}
	else
		((TESTS_FAILED++))
		((TOTAL_TESTS_FAILED++))
		FAILED_CASES+=(${_id_test_name_})
		echo "Expected behaviour not found" | tee -a ${LOG}
		echo "Test failed" | tee -a ${LOG}
	fi
}

# Match the old id with the new id
function match_ids() {
	matched_count=0
	new_id_count=0
	for old in "${old_id_[@]}"
	do
		if [ "${old}" == "${new_id_[new_id_count]}" ]; then
			((matched_count++))
		fi
		((new_id_count++))
	done
}

# Compare the actual result with the expected result
# input: Test name, expected result 
function compare_result() {
	failed=0
	__test__=$1
	expected_result=$2
	expected_log_msg=$3
	test_log=$4

	echo "Test = ${__test__}"
	echo "expected log msg = $expected_log_msg"
	echo "Test log = $test_log"

	if [[ ! ${actual_result} =~ ${expected_result} ]]; then
		failed=1
	else
		if [[ ! -z ${expected_log_msg} ]]; then
			if grep -q "${expected_log_msg}" "${test_log}" ; then
				failed=0
			else
				failed=1
			fi
		else
			failed=1
		fi
	fi

	display_result "${expected_log_msg}" "${__test__}" "${failed}"
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

