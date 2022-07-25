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


function hpo_scale_tests() {
	num_experiments=(1 10 100)
	N_TRIALS=5
	ITERATIONS=3

	for NUM_EXPS in ${num_experiments[@]}
	do
		SCALE_TEST_RES_DIR="${TEST_DIR}/${NUM_EXPS}x-result"
		echo "SCALE_TEST_RES_DIR = ${SCALE_TEST_RES_DIR}"
		mkdir -p "${SCALE_TEST_RES_DIR}"
		run_experiments "${NUM_EXPS}" "${N_TRIALS}" "${SCALE_TEST_RES_DIR}" "${ITERATIONS}"

		${SCRIPTS_DIR}/parsemetrics-promql.sh ${ITERATIONS} ${SCALE_TEST_RES_DIR} ${hpo_instances} ${WARMUP_CYCLES} ${MEASURE_CYCLES} ${SCRIPTS_DIR}

	done

	echo "Results of experiments"
	#echo "INSTANCES ,  CPU_USAGE , MEM_USAGE , FS_USAGE , NW_RECEIVE_BANDWIDTH_USAGE, NW_TRANSMIT_BANDWIDTH_USAGE, CPU_MIN , CPU_MAX , MEM_MIN , MEM_MAX , FS_MIN , FS_MAX NW_RECEIVE_BANDWIDTH_MIN , NW_RECEIVE_BANDWIDTH_MAX , NW_TRANSMIT_BANDWIDTH_MIN , NW_TRANSMIT_BANDWIDTH_MAX" > ${TESTS_DIR}/res_usage_output.csv
	for NUM_EXPS in ${num_experiments[@]}
	do
		cat "${TEST_DIR}/${NUM_EXPS}x-result/Metrics-prom.log"
		#paste "${TEST_DIR}/${NUM_EXPS}x-result/Metrics-prom.log" >> "${TEST_DIR}/res_usage_output.csv"
	done
}

function run_experiments() {
	NUM_EXPS=$1
	N_TRIALS=$2
	RESULTS_=$3
	ITERATIONS=$4

	TRIAL_DURATION=10
	BUFFER=5

	DURATION=`expr $NUM_EXPS \* $TRIAL_DURATION \* $N_TRIALS + $BUFFER`
	#DURATION=300

	WARMUP_CYCLES=0
	MEASURE_CYCLES=1

	# No. of instances of HPO
	hpo_instances=1

	for (( iter=0; iter<${ITERATIONS}; iter++ ))
	do
		
		echo "*************************************************" | tee -a ${LOG}
		echo "Starting Iteration $iter" | tee -a ${LOG}
		echo "*************************************************" | tee -a ${LOG}
		echo ""

		# Deploy HPO 
		RESULTS_I="${RESULTS_}/ITR-${iter}"
		mkdir -p "${RESULTS_I}"
		SERV_LOG="${RESULTS_I}/service.log"

		echo "RESULTSDIR - ${RESULTS_I}" | tee -a ${LOG}
		echo "" | tee -a ${LOG}
		# Deploy hpo
		if [ ${cluster_type} == "native" ]; then
			deploy_hpo ${cluster_type} ${SERV_LOG}
		else
			deploy_hpo ${cluster_type} ${HPO_CONTAINER_IMAGE} ${SERV_LOG}
		fi

		# Check if HPO services are started
		check_server_status "${SERV_LOG}"

		# Measurement runs
		TYPE="measure"
		run_iteration ${NUM_EXPS} ${N_TRIALS} ${DURATION} ${MEASURE_CYCLES} ${TYPE} ${RESULTS_I}

		# Store the docker logs
		if [ ${cluster_type} == "docker" ]; then
			docker logs hpo_docker_container > ${SERV_LOG} 2>&1
		elif [[ ${cluster_type} == "minikube" || ${cluster_type} == "openshift" ]]; then
			hpo_pod=$(kubectl get pod -n ${namespace} | grep hpo | cut -d " " -f1)
	                kubectl -n ${namespace} logs ${hpo_pod} > "${SERV_LOG}" 2>&1
        	fi

		# Terminate any running HPO servers
		echo "Terminating any running HPO servers..." | tee -a ${LOG}
		terminate_hpo ${cluster_type}
		echo "Terminating any running HPO servers...Done" | tee -a ${LOG}
		sleep 2

		echo "*************************************************" | tee -a ${LOG}
		echo "Completed Iteration $iter"
		echo "*************************************************" | tee -a ${LOG}
		echo ""
	
	done

}

function run_iteration() {
	NUM_EXPS=$1
	N_TRIALS=$2
	DURATION=$3
	CYCLES=$4
	TYPE=$5
	RES_DIR=$6

	# Start the metrics collection script
	if [ ${cluster_type} == "openshift" ]; then
	 	BENCHMARK_SERVER=$(oc whoami --show-server  | awk -F[/:] '{print $4}' | sed -e 's/api.//')
	 	BENCHMARK_SERVER="testautotune.lab.pnq2.cee.redhat.com"
	 	BENCHMARK_SERVER="hpoaas2.lab.pnq2.cee.redhat.com"
	else
	 	BENCHMARK_SERVER="${SERVER_IP}"
	fi

	echo "BENCHMARK_SERVER = ${BENCHMARK_SERVER} pod = $hpo_pod"
	APP_NAME="${hpo_pod}"
	# Run experiments
	for (( run=0; run<${CYCLES}; run++ ))
	do
		echo "*************************************************" | tee -a ${LOG}
		echo "Starting $TYPE-$run " | tee -a ${LOG}
		echo "*************************************************" | tee -a ${LOG}
		echo ""

	#	echo "Invoking get metrics cmd - ${SCRIPTS_DIR}/getmetrics-promql.sh ${TYPE}-${run} ${DURATION} ${RES_DIR} ${BENCHMARK_SERVER} ${APP_NAME} ${cluster_type} &"
		${SCRIPTS_DIR}/getmetrics-promql.sh ${TYPE}-${run} ${DURATION} ${RES_DIR} ${BENCHMARK_SERVER} ${APP_NAME} ${cluster_type} &

		hpo_run_experiments "${NUM_EXPS}" "${N_TRIALS}" "${RES_DIR}"

		echo "*************************************************" | tee -a ${LOG}
		echo "Completed $TYPE-$run " | tee -a ${LOG}
		echo "*************************************************" | tee -a ${LOG}
		echo ""
	done


}

# Run Multiple experiments test for HPO REST service
function hpo_run_experiments() {

	# Set the no. of experiments
	NUM_EXPS=$1

	# Set the no. of trials
	N_TRIALS=$2

	exp_dir=$3
	EXP_RES_DIR="${exp_dir}/exp_logs"
	mkdir -p "${EXP_RES_DIR}"

	failed=0

	((TOTAL_TESTS++))
	((TESTS++))

	# Form the url based on cluster type & API
	form_hpo_api_url "experiment_trials"
	echo "HPO URL = $hpo_url"  | tee -a ${LOG}


	echo "RESULTSDIR - ${EXP_RES_DIR}" | tee -a ${LOG}
	echo "" | tee -a ${LOG}

	expected_http_code="200"

	exp_json=${hpo_post_experiment_json["valid-experiment"]}

	## Start multiple experiments
	for (( i=1 ; i<=${NUM_EXPS} ; i++ ))
	do
		LOG_="${EXP_RES_DIR}/hpo-exp-${i}.log"
		# Post the experiment
		echo "Start a new experiment with the search space json..." | tee -a ${LOG}

		# Replace the experiment name
		json=$(echo $exp_json | sed -e 's/petclinic-sample-2-75884c5549-npvgd/petclinic-sample-'${i}'/')
		post_experiment_json "$json"
		verify_result "Post new experiment" "${http_code}" "${expected_http_code}"
	done

	## Loop through the trials
	for (( trial_num=0 ; trial_num<${N_TRIALS} ; trial_num++ ))
	do

		for (( i=1 ; i<=${NUM_EXPS} ; i++ ))
		do
			exp_name="petclinic-sample-${i}"
			echo ""
			echo "*********************************** Experiment ${exp_name} and trial_number ${trial_num} *************************************"
			LOG_="${EXP_RES_DIR}/hpo-exp${i}-trial${trial_num}.log"

			# Get the config from HPO
			sleep 2
			echo ""
			echo "Generate the config for experiment ${i} and trial ${trial_num}..." | tee -a ${LOG}
			echo ""

			curl="curl -H 'Accept: application/json'"

			get_trial_json=$(${curl} ''${hpo_url}'?experiment_name='${exp_name}'&trial_number='${trial_num}'' -w '\n%{http_code}' 2>&1)

			get_trial_json_cmd="${curl} ${hpo_url}?experiment_name="${exp_name}"&trial_number=${trial_num} -w '\n%{http_code}'"
			echo "command used to query the experiment_trial API = ${get_trial_json_cmd}" | tee -a ${LOG}

			http_code=$(tail -n1 <<< "${get_trial_json}")
			response=$(echo -e "${get_trial_json}" | tail -2 | head -1)
			response=$(echo ${response} | cut -c 4-)

			result="${TEST_DIR}/hpo_config_exp${i}_trial${trial_num}.json"
			expected_json="${TEST_DIR}/expected_hpo_config_exp${i}.json"

			echo "${response}" > ${result}
			cat $result
			verify_result "Get config from hpo for experiment ${exp_name} and trial ${trial_num}" "${http_code}" "${expected_http_code}"

			# Added a sleep to mimic experiment run
			sleep 3 

			# Post the experiment result to hpo
			echo "" | tee -a ${LOG}
			echo "Post the experiment result for experiment ${exp_name} and trial ${trial_num}..." | tee -a ${LOG}
			trial_result="success"
			result_value="98.7"
			exp_result_json='{"experiment_name":"'${exp_name}'","trial_number":'${trial_num}',"trial_result":"'${trial_result}'","result_value_type":"double","result_value":'${result_value}',"operation":"EXP_TRIAL_RESULT"}'
			post_experiment_result_json ${exp_result_json}
			verify_result "Post experiment result for experiment ${exp_name} and trial ${trial_num}" "${http_code}" "${expected_http_code}"
	
			sleep 2

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

	for (( i=1 ; i<=${NUM_EXPS} ; i++ ))
	do
		exp_name="\"petclinic-sample-${i}"\"
		stop_experiment='{"experiment_name":'${exp_name}',"operation":"EXP_STOP"}'
		post_experiment_json ${stop_experiment}
		verify_result "Stop running experiment ${exp_name}" "${http_code}" "200"
	done

}
