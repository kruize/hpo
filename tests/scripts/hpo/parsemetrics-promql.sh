#!/bin/bash
#
# Copyright (c) 2020, 2022 IBM Corporation, RedHat and others.
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
### Script to parse prometheus query data###


CURRENT_DIR="$(dirname "$(realpath "$0")")"
source ${CURRENT_DIR}/../utils/common.sh

# Parse CPU, memeory and cluster information
# input:type of run(warmup|measure), total number of runs, iteration number
# output:Creates cpu, memory and cluster information in the form of log files for each run
function parsePromMetrics()  {
	TYPE=$1
	TOTAL_RUNS=$2
	ITR=$3

	for (( run=0 ; run<"${TOTAL_RUNS}" ;run++))
	do
		for poddatalog in "${POD_CPU_LOGS[@]}"
		do
			# Parsing CPU, app metric logs for pod
			parsePodDataLog ${poddatalog} ${TYPE} ${run} ${ITR}
		done
		for podmemlog in "${POD_MEM_LOGS[@]}"
		do
			# Parsing Mem logs for pod
			parsePodMemLog ${podmemlog} ${TYPE} ${run} ${ITR}
		done

		for podfsusagelog in "${POD_FS_USAGE_LOGS[@]}"
		do
			# Parsing Mem logs for pod
			parsePodDataLog ${podfsusagelog} ${TYPE} ${run} ${ITR}
		done

		for podnwlog in "${POD_NW_LOGS[@]}"
		do
			# Parsing Network logs for pod
			parsePodDataLog ${podnwlog} ${TYPE} ${run} ${ITR}
		done
	done

}

# Parsing CPU logs for pod
# input: podcpulogs array element, type of run(warmup|measure), run(warmup|measure) number, iteration number
# output:creates cpu log for pod
function parsePodDataLog()
{
	MODE=$1
	TYPE=$2
	RUN=$3
	ITR=$4
	RESULTS_LOG=${MODE}-${TYPE}-${ITR}.log
	data_sum=0
	data_min=0
	data_max=0
	DATA_LOG=${RESULTS_DIR_P}/${MODE}-${TYPE}-${RUN}.json
	RUN_PODS=($(cat ${DATA_LOG} | cut -d ";" -f2 | sort | uniq))

	TEMP_LOG=${RESULTS_DIR_P}/temp-data-${MODE}.log
	for run_pod in "${RUN_PODS[@]}"
	do
		if [ -s "${DATA_LOG}" ]; then
                        cat ${DATA_LOG} | grep ${run_pod} | cut -d ";" -f4 | cut -d '"' -f1 > ${TEMP_LOG}
                        each_pod_data_avg=$( echo `calcAvg ${TEMP_LOG} | cut -d "=" -f2`  )
                        each_pod_data_min=$( echo `calcMin ${TEMP_LOG}` )
                        each_pod_data_max=$( echo `calcMax ${TEMP_LOG}` )
                        data_sum=$(echo ${data_sum}+${each_pod_data_avg}| bc -l)
                        data_min=$(echo ${data_min}+${each_pod_data_min}| bc -l)
                        data_max=$(echo ${data_max}+${each_pod_data_max} | bc -l)
                fi
	done
	echo "${run} , ${data_sum}, ${data_min} , ${data_max}" >> ${RESULTS_DIR_J}/${RESULTS_LOG}
	echo ",${data_sum} , ${data_min} , ${data_max}" >> ${RESULTS_DIR_J}/${MODE}-${TYPE}-raw.log
}

# Parsing memory logs for pod
# input: podmemlogs array element, type of run(warmup|measure), run(warmup|measure) number, iteration number
# output:creates memory log for pod
function parsePodMemLog()
{
	MODE=$1
	TYPE=$2
	RUN=$3
	ITR=$4
	RESULTS_LOG=${MODE}-${TYPE}-${ITR}.log
	mem_sum=0
	mem_min=0
	mem_max=0

	MEM_LOG=${RESULTS_DIR_P}/${MODE}-${TYPE}-${RUN}.json
	MEM_PODS=($(cat ${MEM_LOG} | cut -d ";" -f2 | sort | uniq))

	TEMP_LOG=${RESULTS_DIR_P}/temp-mem-${MODE}.log
	for mem_pod in "${MEM_PODS[@]}"
	do
		if [ -s "${MEM_LOG}" ]; then
                        cat ${MEM_LOG} | grep ${mem_pod} | cut -d ";" -f4 | cut -d '"' -f1 > ${TEMP_LOG}
                        each_pod_mem_avg=$( echo `calcAvg_inMB ${TEMP_LOG} | cut -d "=" -f2`  )
                        each_pod_mem_min=$( echo `calcMin ${TEMP_LOG}`  )
                        each_pod_mem_min_inMB=$(echo ${each_pod_mem_min}/1024/1024 | bc)
                        each_pod_mem_max=$( echo `calcMax ${TEMP_LOG}`  )
                        each_pod_mem_max_inMB=$(echo ${each_pod_mem_max}/1024/1024 | bc)
                        mem_sum=$(echo ${mem_sum}+${each_pod_mem_avg} | bc)
                        mem_min=$(echo ${mem_min}+${each_pod_mem_min_inMB} | bc)
                        mem_max=$(echo ${mem_max}+${each_pod_mem_max_inMB} | bc)
                fi
	done
	echo "${run} , ${mem_sum}, ${mem_min} , ${mem_max} " >> ${RESULTS_DIR_J}/${RESULTS_LOG}
	echo ", ${mem_sum} , ${mem_min} , ${mem_max} " >> ${RESULTS_DIR_J}/${MODE}-${TYPE}-raw.log
}

# Parsing memory logs for pod
# input: clusterlogs array element, json file with cluster information, result log file
# output:creates clsuter log file
function parseClusterLog() {
	MODE=$1
	CLUSTER_LOG=$2
	CLUSTER_RESULTS_LOG=$3
	if [ -s ${CLUSTER_LOG} ]; then
                cat ${CLUSTER_LOG}| cut -d ";" -f2 | cut -d '"' -f1 | grep -Eo '[0-9\.]+' > C_temp.log
                cluster_cpumem=$( echo `calcAvg_in_p C_temp.log | cut -d "=" -f2`  )
        fi
	echo "${run} , ${cluster_cpumem}" >> ${RESULTS_DIR_J}/${CLUSTER_RESULTS_LOG}
}

# Parse the results of jmeter load for each instance of application
# input: total number of iterations, result directory, Total number of instances
# output: Parse the results and generate the Metrics log files
function parseResults() {
	TOTAL_ITR=$1
	RESULTS_DIR_J=$2
	SCALE=$3
	WARMUPS=$4
	MEASURES=$5

	for (( itr=0 ; itr<${TOTAL_ITR} ;itr++))
	do
		RESULTS_DIR_P=${RESULTS_DIR_J}/ITR-${itr}
		parsePromMetrics warmup ${WARMUPS} ${itr}
		parsePromMetrics measure ${MEASURES} ${itr}

		for poddatalog in "${POD_CPU_LOGS[@]}"
		do
			if [ -s "${RESULTS_DIR_J}/${poddatalog}-measure-${itr}.log" ]; then
                                cat ${RESULTS_DIR_J}/${poddatalog}-measure-${itr}.log | cut -d "," -f2 >> ${RESULTS_DIR_J}/${poddatalog}-measure-temp.log
                                cat ${RESULTS_DIR_J}/${poddatalog}-measure-${itr}.log | cut -d "," -f3 >> ${RESULTS_DIR_J}/${poddatalog}_min-measure-temp.log
                                cat ${RESULTS_DIR_J}/${poddatalog}-measure-${itr}.log | cut -d "," -f4 >> ${RESULTS_DIR_J}/${poddatalog}_max-measure-temp.log
                        fi
		done
		for podmemlog in "${POD_MEM_LOGS[@]}"
		do
			if [ -s "${RESULTS_DIR_J}/${podmemlog}-measure-${itr}.log" ]; then
                                cat ${RESULTS_DIR_J}/${podmemlog}-measure-${itr}.log | cut -d "," -f2 >> ${RESULTS_DIR_J}/${podmemlog}-measure-temp.log
                                cat ${RESULTS_DIR_J}/${podmemlog}-measure-${itr}.log | cut -d "," -f3 >> ${RESULTS_DIR_J}/${podmemlog}_min-measure-temp.log
                                cat ${RESULTS_DIR_J}/${podmemlog}-measure-${itr}.log | cut -d "," -f4 >> ${RESULTS_DIR_J}/${podmemlog}_max-measure-temp.log
                        fi
		done
		for podfsusagelog in "${POD_FS_USAGE_LOGS[@]}"
		do
			if [ -s "${RESULTS_DIR_J}/${podfsusagelog}-measure-${itr}.log" ]; then
                                cat ${RESULTS_DIR_J}/${podfsusagelog}-measure-${itr}.log | cut -d "," -f2 >> ${RESULTS_DIR_J}/${podfsusagelog}-measure-temp.log
                                cat ${RESULTS_DIR_J}/${podfsusagelog}-measure-${itr}.log | cut -d "," -f3 >> ${RESULTS_DIR_J}/${podfsusagelog}_min-measure-temp.log
                                cat ${RESULTS_DIR_J}/${podfsusagelog}-measure-${itr}.log | cut -d "," -f4 >> ${RESULTS_DIR_J}/${podfsusagelog}_max-measure-temp.log
                        fi
		done

		for podnwlog in "${POD_NW_LOGS[@]}"
		do
			if [ -s "${RESULTS_DIR_J}/${podnwlog}-measure-${itr}.log" ]; then
                                cat ${RESULTS_DIR_J}/${podnwlog}-measure-${itr}.log | cut -d "," -f2 >> ${RESULTS_DIR_J}/${podnwlog}-measure-temp.log
                                cat ${RESULTS_DIR_J}/${podnwlog}-measure-${itr}.log | cut -d "," -f3 >> ${RESULTS_DIR_J}/${podnwlog}_min-measure-temp.log
                                cat ${RESULTS_DIR_J}/${podnwlog}-measure-${itr}.log | cut -d "," -f4 >> ${RESULTS_DIR_J}/${podnwlog}_max-measure-temp.log
                        fi
		done
	done
	###### Add different raw logs we want to merge
	#Cumulative raw data
	paste ${RESULTS_DIR_J}/cpu-measure-raw.log ${RESULTS_DIR_J}/mem-measure-raw.log >> ${RESULTS_DIR_J}/Metrics-cpumem-raw.log

	for metric in "${TOTAL_LOGS[@]}"
	do
		if [ -s ${RESULTS_DIR_J}/${metric}-measure-temp.log ]; then
		if [ ${metric} == "cpu_min" ] || [ ${metric} == "mem_min" ] || [ ${metric} == "fsusage_min" ] || [ ${metric} == "receive_bandwidth_min" ] || [ ${metric} == "transmit_bandwidth_min" ]; then
			minval=$(echo `calcMin ${RESULTS_DIR_J}/${metric}-measure-temp.log`)
			if [ ! -z ${minval} ]; then
				eval total_${metric}=${minval}
			else
				eval total_${metric}=0
			fi
		elif [ ${metric} == "cpu_max" ] || [ ${metric} == "mem_max" ] || [ ${metric} == "latency_seconds_max" ] || [ ${metric} == "server_requests_max" ] || [ ${metric} == "fsusage_max" ] || [ ${metric} == "receive_bandwidth_max" ] || [ ${metric} == "transmit_bandwidth_max" ]; then
			maxval=$(echo `calcMax ${RESULTS_DIR_J}/${metric}-measure-temp.log`)
			if [ ! -z ${maxval} ]; then
				eval total_${metric}=${maxval}
			else
				eval total_${metric}=0
			fi
		else
			val=$(echo `calcAvg ${RESULTS_DIR_J}/${metric}-measure-temp.log | cut -d "=" -f2`)
			if [ ! -z ${val} ]; then
				eval total_${metric}_avg=${val}
			else
				eval total_${metric}_avg=0
			fi
		fi

		# Calculate confidence interval
		metric_ci=`php ${SCRIPT_REPO}/../utils/ci.php ${RESULTS_DIR_J}/${metric}-measure-temp.log`
		if [ ! -z ${metric_ci} ]; then
			eval ci_${metric}=${metric_ci}
		else
			eval ci_${metric}=0
		fi

		fi
	done

#	echo "INSTANCES ,  CPU_USAGE , MEM_USAGE , FS_USAGE , NW_RECEIVE_USAGE, NWTRANSMIT_USAGE, CPU_MIN , CPU_MAX , MEM_MIN , MEM_MAX , FS_MIN , FS_MAX NW_RECEIVE_MIN , NW_RECEIVE_MAX , NW_TRANSMIT_MIN , NW_TRANSMIT_MAX" > ${RESULTS_DIR_J}/Metrics-prom.log

	echo "${SCALE} , ${total_cpu_avg} , ${total_mem_avg} , ${total_fsusage_avg} , ${total_receive_bandwidth_avg} , ${total_transmit_bandwidth_avg} , ${total_cpu_min} , ${total_cpu_max} , ${total_mem_min} , ${total_mem_max} , ${total_fsusage_min} , ${total_fsusage_max} , ${total_receive_bandwidth_min} , ${total_receive_bandwidth_max} , ${total_transmit_bandwidth_min} , ${total_transmit_bandwidth_max}" >> ${RESULTS_DIR_J}/Metrics-prom.log

        echo "${SCALE} ,  ${total_mem_avg} , ${total_memusage_avg} " >> ${RESULTS_DIR_J}/Metrics-mem-prom.log
        echo "${SCALE} ,  ${total_cpu_avg} " >> ${RESULTS_DIR_J}/Metrics-cpu-prom.log

        echo "${SCALE} , ${total_maxspike_cpu_max} , ${total_maxspike_mem_max} "  >> ${RESULTS_DIR_J}/Metrics-spikes-prom.log

}

POD_CPU_LOGS=(cpu)
POD_MEM_LOGS=(mem memusage)
POD_FS_USAGE_LOGS=(fsusage)
POD_NW_LOGS=(receive_bandwidth transmit_bandwidth) 

CLUSTER_LOGS=(c_mem c_cpu)

TOTAL_LOGS=(${POD_CPU_LOGS[@]} ${POD_MEM_LOGS[@]} ${POD_FS_USAGE_LOGS[@]} ${POD_NW_LOGS[@]} cpu_min cpu_max mem_min mem_max fsuage_min fsusage_max receive_bandwidth_min receive_bandwidth_max transmit_bandwidth_min transmit_bandwidth_max)


TOTAL_ITR=$1
RESULTS_DIR_J=$2
SCALE=$3
WARMUPS=$4
MEASURES=$5
SCRIPT_REPO=$6

parseResults ${TOTAL_ITR} ${RESULTS_DIR_J} ${SCALE} ${WARMUPS} ${MEASURES} ${SCRIPT_REPO}
