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
##### Functional tests for hpo #####
#

CURRENT_DIR="$(dirname "$(realpath "$0")")"
SCRIPTS_DIR="${CURRENT_DIR}" 

# Source the common functions scripts
. ${SCRIPTS_DIR}/common/common_functions.sh

# Source the test suite scripts
. ${SCRIPTS_DIR}/hpo/hpo_scale_tests.sh

# Iterate through the commandline options
while getopts o:n:-: gopts
do
	case ${gopts} in
	-)
		case "${OPTARG}" in
			cluster_type=*)
				cluster_type=${OPTARG#*=}
				;;
			tctype=*)
				tctype=${OPTARG#*=}
				;;
			testmodule=*)
				testmodule=${OPTARG#*=}
				;;
			testsuite=*)
				testsuite=${OPTARG#*=}
				;;
			testcase=*)
				testcase=${OPTARG#*=}
				;;
			resultsdir=*)
				resultsdir=${OPTARG#*=}
				;;
		esac
		;;
	o)
		HPO_CONTAINER_IMAGE="${OPTARG}"		
		;;
	n)
		namespace="${OPTARG}"
		;;
	esac
done

# Set the root for result directory 
if [ -z "${resultsdir}" ]; then
	RESULTS_ROOT_DIR="${PWD}/hpo_system_test_results"
else
	RESULTS_ROOT_DIR="${resultsdir}/hpo_system_test_results"
fi
mkdir -p ${RESULTS_ROOT_DIR}

# create the result directory with a time stamp
RESULTS_DIR="${RESULTS_ROOT_DIR}/hpo_$(date +%Y%m%d:%T)"
mkdir -p "${RESULTS_DIR}"

SETUP_LOG="${RESULTS_DIR}/setup.log"

function system_tests() {
	execute_system_testsuites
}

# Execute all tests for HPO (Hyperparameter Optimization) module
function execute_system_testsuites() {
	testcase=""
	# perform the HPO scale tests
	hpo_scale_tests > >(tee "${RESULTS_DIR}/hpo_scale_tests.log") 2>&1
}

# Perform the specific testsuite if specified 
if [ -z "${testsuite}" ]; then
	echo ""
	echo "Usage: ./test_hpo.sh -c [cluster_type] -o [HPO Container image] --testsuite=hpo_scale_tests"
	echo "testsuite should be specified: --testsuite=hpo_scale_tests"
	echo ""
	exit 1
else
	${testsuite} > >(tee "${RESULTS_DIR}/${testsuite}.log") 2>&1
fi

echo ""
echo "*********************************************************************************"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Test Completed  ~~~~~~~~~~~~~~~~~~~~~~~"
echo "*********************************************************************************"


