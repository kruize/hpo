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
. ${SCRIPTS_DIR}/hpo_post_experiment_tests.sh
. ${SCRIPTS_DIR}/hpo_get_config_tests.sh
. ${SCRIPTS_DIR}/hpo_post_exp_result_tests.sh
. ${SCRIPTS_DIR}/hpo_multiple_exp_tests.sh
. ${SCRIPTS_DIR}/hpo_sanity_tests.sh

# Tests to validate the HPO APIs
function hpo_api_tests() {
	start_time=$(get_date)
	FAILED_CASES=()
	TESTS_FAILED=0
	TESTS_PASSED=0
	TESTS=0
	((TOTAL_TEST_SUITES++))

	hpo_api_tests=("hpo_post_experiment" "hpo_grpc_post_experiment" "hpo_get_trial_json" "hpo_post_exp_result" "hpo_grpc_post_exp_result" "hpo_sanity_test" "hpo_grpc_sanity_test" "hpo_multiple_exp_test" 
			"hpo_grpc_multiple_exp_test")

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

