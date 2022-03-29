#!/bin/bash
#
# Copyright (c) 2021, 2022 Red Hat, IBM Corporation and others.
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
#########################################################################################
#    This script is to run the benchmark as part of trial in an experiment.             #
#    All the tunables configuration from optuna are inputs to benchmark.                #
#    This script has only techempower as the benchmark.                                 #
#                                                                                       #
#########################################################################################

cpu_request=$1
memory_request=$2
envoptions=$3

BENCHMARK_NAME="techempower"

if [[ ${BENCHMARK_NAME} == "techempower" ]]; then

CLUSTER_TYPE="minikube"
BENCHMARK_SERVER="localhost"
RESULTS_DIR="results"
TFB_IMAGE="kusumach/tfb-qrh:1.13.2.F_mm_p"
DB_TYPE="docker"
DURATION="60"
WARMUPS=1
MEASURES=3
SERVER_INSTANCES=1
ITERATIONS=1
NAMESPACE="default"
THREADS="40"
CONNECTIONS="512"

./benchmarks/techempower/scripts/perf/tfb-run.sh --clustertype=${CLUSTER_TYPE} -s ${BENCHMARK_SERVER} -e ${RESULTS_DIR} -g ${TFB_IMAGE} --dbtype=${DB_TYPE} --dbhost=${DB_HOST} -r -d ${DURATION} -w ${WARMUPS} -m ${MEASURES} -i ${SERVER_INSTANCES} --iter=${ITERATIONS} -n ${NAMESPACE} -t ${THREADS} --connection=${CONNECTIONS} --cpureq=${cpu_request} --memreq=${memory_request}M --cpulim=${cpu_request} --memlim=${memory_request}M --envoptions="${envoptions}"

fi
