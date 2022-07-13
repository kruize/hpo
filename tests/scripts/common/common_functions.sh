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
