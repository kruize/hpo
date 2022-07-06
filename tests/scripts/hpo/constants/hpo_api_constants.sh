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
##### Constants for HPO API tests #####
#

# Brief description about the HPO API tests
declare -A hpo_api_test_description
hpo_api_test_description=([hpo_post_experiment]="Start the required HPO services, post an experiment json to HPO /experiment_trials API with various combinations and validate the result"
                          [hpo_get_trial_json]="Start the required HPO services post a valid experiment json to HPO /experiment_trials API, query the API using different combinations of experiment id and trial_number and validate the result" 
                          [hpo_post_exp_result]="Start the required HPO services, post a valid experiment json to HPO /experiment_trials API and then post valid and invalid combinations of experiment result to the API and validate the result"
			  [hpo_sanity_test]="Start the required HPO services, post a valid experiment json to HPO /experiment_trials API, get the config, post the experiment result and subsequent experiment repeatedly for the specified number of trials"
			  [hpo_grpc_sanity_test]="Start the required HPO services, post a valid experiment json to HPO /experiment_trials API, get the config, post the experiment result and subsequent experimentrepeatedly for the specified number of trials")

# Tests to be carried out for HPO (Hyper Parameter Optimization) module API to post an experiment
run_post_experiment_tests=(
"empty-id"
"no-id"
"null-id"
"empty-name"
"no-name"
"null-name"
"invalid-operation"
"empty-operation"
"no-operation"
"null-operation"
"valid-experiment"
"additional-field"
"generate-subsequent"
"invalid-searchspace")

other_post_experiment_tests=("post-duplicate-experiments" "operation-generate-subsequent")

# Tests to be carried out for HPO module API to get trial json  
declare -A hpo_get_trial_json_tests
hpo_get_trial_json_tests=([get_trial_json_invalid_tests]='empty-name no-name null-name only-valid-name invalid-trial-number empty-trial-number no-trial-number null-trial-number only-valid-trial-number'
                             [get_trial_json_valid_tests]='valid-exp-trial valid-exp-trial-generate-subsequent')


declare -A hpo_get_trial_msgs
hpo_get_trial_msgs=(
[empty-name]="Parameters cannot be empty or null"
[no-name]="Missing required parameters"
[null-name]="Parameters cannot be empty or null"
[only-valid-name]="Missing required parameters"
[invalid-trial-number]="Missing required parameters"
[empty-trial-number]="Missing required parameters"
[no-trial-number]="Missing required parameters"
[null-trial-number]="Missing required parameters"
[only-valid-trial-number]="Missing required parameters"

)

# Tests to be carried out for HPO module API to post experiment results 
run_post_exp_result_tests=("empty-name"
"no-name"
"null-name"
"invalid-trial-number"
"no-trial-number"
"null-trial-number"
"invalid-trial-result"
"empty-trial-result"
"no-trial-result"
"null-trial-result"
"invalid-result-value-type"
"empty-result-value-type"
"no-result-value-type"
"null-result-value-type"
"invalid-result-value"
"no-result-value"
"null-result-value"
"invalid-operation"
"empty-operation"
"no-operation"
"null-operation"
"valid-experiment-result"
"additional-field"
)

other_exp_result_post_tests=("post-duplicate-exp-result" "post-same-id-different-exp-result")

declare -A hpo_post_experiment_json=(

	[empty-id]='{"operation":"EXP_TRIAL_GENERATE_NEW","search_space":{"experiment_name":"petclinic-sample-2-75884c5549-npvgd","total_trials":5,"parallel_trials":1,"experiment_id":" ","value_type":"double","hpo_algo_impl":"optuna_tpe","objective_function":"transaction_response_time","tunables":[{"value_type":"double","lower_bound":150,"name":"memoryRequest","upper_bound":300,"step":1},{"value_type":"double","lower_bound":1,"name":"cpuRequest","upper_bound":3,"step":0.01}],"direction":"minimize"}}'

	[no-id]='{"operation":"EXP_TRIAL_GENERATE_NEW","search_space":{"experiment_name":"petclinic-sample-2-75884c5549-npvgd","total_trials":5,"parallel_trials":1,"value_type":"double","hpo_algo_impl":"optuna_tpe","objective_function":"transaction_response_time","tunables":[{"value_type":"double","lower_bound":150,"name":"memoryRequest","upper_bound":300,"step":1},{"value_type":"double","lower_bound":1,"name":"cpuRequest","upper_bound":3,"step":0.01}],"direction":"minimize"}}'

	[null-id]='{"operation":"EXP_TRIAL_GENERATE_NEW","search_space":{"experiment_name":"petclinic-sample-2-75884c5549-npvgd","total_trials":5,"parallel_trials":1,"experiment_id":null,"value_type":"double","hpo_algo_impl":"optuna_tpe","objective_function":"transaction_response_time","tunables":[{"value_type":"double","lower_bound":150,"name":"memoryRequest","upper_bound":300,"step":1},{"value_type":"double","lower_bound":1,"name":"cpuRequest","upper_bound":3,"step":0.01}],"direction":"minimize"}}'
	
	[empty-name]='{"operation":"EXP_TRIAL_GENERATE_NEW","search_space":{"experiment_name":" ","total_trials":5,"parallel_trials":1,"experiment_id":"a123","value_type":"double","hpo_algo_impl":"optuna_tpe","objective_function":"transaction_response_time","tunables":[{"value_type":"double","lower_bound":150,"name":"memoryRequest","upper_bound":300,"step":1},{"value_type":"double","lower_bound":1,"name":"cpuRequest","upper_bound":3,"step":0.01}],"direction":"minimize"}}'

	[no-name]='{"operation":"EXP_TRIAL_GENERATE_NEW","search_space":{"total_trials":5,"parallel_trials":1,"experiment_id":"a123","value_type":"double","hpo_algo_impl":"optuna_tpe","objective_function":"transaction_response_time","tunables":[{"value_type":"double","lower_bound":150,"name":"memoryRequest","upper_bound":300,"step":1},{"value_type":"double","lower_bound":1,"name":"cpuRequest","upper_bound":3,"step":0.01}],"direction":"minimize"}}'

	[null-name]='{"operation":"EXP_TRIAL_GENERATE_NEW","search_space":{"experiment_name":null,"total_trials":5,"parallel_trials":1,"experiment_id":"a123","value_type":"double","hpo_algo_impl":"optuna_tpe","objective_function":"transaction_response_time","tunables":[{"value_type":"double","lower_bound":150,"name":"memoryRequest","upper_bound":300,"step":1},{"value_type":"double","lower_bound":1,"name":"cpuRequest","upper_bound":3,"step":0.01}],"direction":"minimize"}}'

	[invalid-operation]='{"operation":"EXP_TRIAL_GENERATE_CURRENT","search_space":{"experiment_name":"petclinic-sample-2-75884c5549-npvgd","total_trials":5,"parallel_trials":1,"experiment_id":"a123","value_type":"double","hpo_algo_impl":"optuna_tpe","objective_function":"transaction_response_time","tunables":[{"value_type":"double","lower_bound":150,"name":"memoryRequest","upper_bound":300,"step":1},{"value_type":"double","lower_bound":1,"name":"cpuRequest","upper_bound":3,"step":0.01}],"direction":"minimize"}}'

	[empty-operation]='{"operation":" ","search_space":{"experiment_name":"petclinic-sample-2-75884c5549-npvgd","total_trials":5,"parallel_trials":1,"experiment_id":"a123","value_type":"double","hpo_algo_impl":"optuna_tpe","objective_function":"transaction_response_time","tunables":[{"value_type":"double","lower_bound":150,"name":"memoryRequest","upper_bound":300,"step":1},{"value_type":"double","lower_bound":1,"name":"cpuRequest","upper_bound":3,"step":0.01}],"direction":"minimize"}}'

	[no-operation]='{"search_space":{"experiment_name":"petclinic-sample-2-75884c5549-npvgd","total_trials":5,"parallel_trials":1,"experiment_id":"a123","value_type":"double","hpo_algo_impl":"optuna_tpe","objective_function":"transaction_response_time","tunables":[{"value_type":"double","lower_bound":150,"name":"memoryRequest","upper_bound":300,"step":1},{"value_type":"double","lower_bound":1,"name":"cpuRequest","upper_bound":3,"step":0.01}],"direction":"minimize"}}'

	[null-operation]='{"operation":null,"search_space":{"experiment_name":"petclinic-sample-2-75884c5549-npvgd","total_trials":5,"parallel_trials":1,"experiment_id":"a123","value_type":"double","hpo_algo_impl":"optuna_tpe","objective_function":"transaction_response_time","tunables":[{"value_type":"double","lower_bound":150,"name":"memoryRequest","upper_bound":300,"step":1},{"value_type":"double","lower_bound":1,"name":"cpuRequest","upper_bound":3,"step":0.01}],"direction":"minimize"}}'

	[additional-field]='{"operation":"EXP_TRIAL_GENERATE_NEW","search_space":{"experiment_name":"petclinic-sample-2-75884c5549-npvgd","total_trials":5,"parallel_trials":1,"experiment_id":"a123","value_type":"double","hpo_algo_impl":"optuna_tpe","objective_function":"transaction_response_time","tunables":[{"value_type":"double","lower_bound":150,"name":"memoryRequest","upper_bound":300,"step":1},{"value_type":"double","lower_bound":1,"name":"cpuRequest","upper_bound":3,"step":0.01}],"direction":"minimize"},"cpu":"cputunable"}'

	[valid-experiment]='{"operation":"EXP_TRIAL_GENERATE_NEW","search_space":{"experiment_name":"petclinic-sample-2-75884c5549-npvgd","total_trials":5,"parallel_trials":1,"experiment_id":"a123","value_type":"double","hpo_algo_impl":"optuna_tpe","objective_function":"transaction_response_time","tunables":[{"value_type":"double","lower_bound":150,"name":"memoryRequest","upper_bound":300,"step":1},{"value_type":"double","lower_bound":1,"name":"cpuRequest","upper_bound":3,"step":0.01}],"direction":"minimize"}}'

	[generate-subsequent]='{"experiment_name":"petclinic-sample-2-75884c5549-npvgd","operation":"EXP_TRIAL_GENERATE_SUBSEQUENT"}'

	[invalid-searchspace]='{"operation":"EXP_TRIAL_GENERATE_NEW","search_space":{"experiment_name":"petclinic-sample-2-75884c5549-npvgd","total_trials":5,"parallel_trials":1,"experiment_id":"a123","value_type":"double","hpo_algo_impl":"optuna_tpe","objective_function":"transaction_response_time","tunables":[{"value_type":"double","lower_bound":150,"name":"memoryRequest","upper_bound":300,"step":1},{"value_type":"double","lower_bound":1,"name":"cpuRequest","upper_bound":3,"step":0.01}],"direction":"xyz"}}'
)

declare -A hpo_error_messages
<<<<<<< HEAD
<<<<<<< HEAD
=======
>>>>>>> 923ef1f (Split the tests based on functionality instead of  service)
hpo_error_messages=(
[empty-id]="Parameters cannot be empty or null"
[no-id]="'experiment_id' is a required property"
[null-id]="Parameters cannot be empty or null"
[empty-name]="Parameters cannot be empty or null"
[no-name]="'experiment_name' is a required property"
[null-name]="Parameters cannot be empty or null"
[invalid-operation]="Invalid Operation value"
[empty-operation]="Parameters cannot be empty or null"
[no-operation]="'operation' is a required property"
[null-operation]="Parameters cannot be empty or null"
[additional-field]="Additional properties are not allowed"
[valid-experiment]="Starting Experiment"
[generate-subsequent]="Experiment not found"
[invalid-searchspace]="Direction not supported"
)
<<<<<<< HEAD
=======
hpo_error_messages=([empty-id]="KeyError: ' '"
[no-id]="KeyError: 'experiment_id'"
[null-id]="KeyError: None"
[empty-name]="KeyError: ' '"
[no-name]="KeyError: 'experiment_name'"
[null-name]="KeyError: None"
[no-operation]="KeyError: 'operation'")
>>>>>>> 2e1c695 (Rebased the changes again and removed invalid id test as it is no longer relevant)
=======
>>>>>>> 923ef1f (Split the tests based on functionality instead of  service)


declare -A hpo_post_exp_result_json=([empty-name]='{"experiment_name" : " ", "trial_number": 0, "trial_result": "success", "result_value_type": "double", "result_value": 98.78, "operation" : "EXP_TRIAL_RESULT"}'
	[no-name]='{"trial_number": 0, "trial_result": "success", "result_value_type": "double", "result_value": 98.78, "operation" : "EXP_TRIAL_RESULT"}'
	[null-name]='{"experiment_name" : null, "trial_number": 0, "trial_result": "success", "result_value_type": "double", "result_value": 98.78, "operation" : "EXP_TRIAL_RESULT"}'

	[invalid-trial-number]='{"experiment_name" : "petclinic-sample-2-75884c5549-npvgd", "trial_number": 10000, "trial_result": "success", "result_value_type": "double", "result_value": 98.78, "operation" : "EXP_TRIAL_RESULT"}'
	[no-trial-number]='{"experiment_name" : "petclinic-sample-2-75884c5549-npvgd", "trial_result": "success", "result_value_type": "double", "result_value": 98.78, "operation" : "EXP_TRIAL_RESULT"}'
	[null-trial-number]='{"experiment_name" : "petclinic-sample-2-75884c5549-npvgd", "trial_number": null, "trial_result": "success", "result_value_type": "double", "result_value": 98.78, "operation" : "EXP_TRIAL_RESULT"}'
	[invalid-trial-result]='{"experiment_name" : "petclinic-sample-2-75884c5549-npvgd", "trial_number": 0, "trial_result": "xyz", "result_value_type": "double", "result_value": 98.78, "operation" : "EXP_TRIAL_RESULT"}'
	[empty-trial-result]='{"experiment_name" : "petclinic-sample-2-75884c5549-npvgd", "trial_number": 0, "trial_result": " ", "result_value_type": "double", "result_value": 98.78, "operation" : "EXP_TRIAL_RESULT"}'
	[no-trial-result]='{"experiment_name" : "petclinic-sample-2-75884c5549-npvgd", "trial_number": 0, "result_value_type": "double", "result_value": 98.78, "operation" : "EXP_TRIAL_RESULT"}'
	[null-trial-result]='{"experiment_name" : "petclinic-sample-2-75884c5549-npvgd", "trial_number": 0, "trial_result": null, "result_value_type": "double", "result_value": 98.78, "operation" : "EXP_TRIAL_RESULT"}'
	[invalid-result-value-type]='{"experiment_name" : "petclinic-sample-2-75884c5549-npvgd", "trial_number": 0, "trial_result": "success", "result_value_type": "xyz", "result_value": 98.78, "operation" : "EXP_TRIAL_RESULT"}'
	[empty-result-value-type]='{"experiment_name" : "petclinic-sample-2-75884c5549-npvgd", "trial_number": 0, "trial_result": "success", "result_value_type": " ", "result_value": 98.78, "operation" : "EXP_TRIAL_RESULT"}'
	[no-result-value-type]='{"experiment_name" : "petclinic-sample-2-75884c5549-npvgd", "trial_number": 0, "trial_result": "success", "result_value": 98.78, "operation" : "EXP_TRIAL_RESULT"}'
	[null-result-value-type]='{"experiment_name" : "petclinic-sample-2-75884c5549-npvgd", "trial_number": 0, "trial_result": "success", "result_value_type": null, "result_value": 98.78, "operation" : "EXP_TRIAL_RESULT"}'
	[invalid-result-value]='{"experiment_name" : "petclinic-sample-2-75884c5549-npvgd", "trial_number": 0, "trial_result": "success", "result_value_type": "double", "result_value": -98.68, "operation" : "EXP_TRIAL_RESULT"}'
	[no-result-value]='{"experiment_name" : "petclinic-sample-2-75884c5549-npvgd", "trial_number": 0, "trial_result": "success", "result_value_type": "double", "operation" : "EXP_TRIAL_RESULT"}'
	[null-result-value]='{"experiment_name" : "petclinic-sample-2-75884c5549-npvgd", "trial_number": 0, "trial_result": "success", "result_value_type": "double", "result_value": null, "operation" : "EXP_TRIAL_RESULT"}'
	[invalid-operation]='{"experiment_name" : "petclinic-sample-2-75884c5549-npvgd", "trial_number": 0, "trial_result": "success", "result_value_type": "double", "result_value": 98.78, "operation" : "xyz"}'
	[empty-operation]='{"experiment_name" : "petclinic-sample-2-75884c5549-npvgd", "trial_number": 0, "trial_result": "success", "result_value_type": "double", "result_value": 98.78, "operation" : " "}'
	[no-operation]='{"experiment_name" : "petclinic-sample-2-75884c5549-npvgd", "trial_number": 0, "trial_result": "success", "result_value_type": "double", "result_value": 98.78}'
	[null-operation]='{"experiment_name" : "petclinic-sample-2-75884c5549-npvgd", "trial_number": 0, "trial_result": "success", "result_value_type": "double", "result_value": 98.78, "operation" : null}'
	[additional-field]='{"experiment_name" : "petclinic-sample-2-75884c5549-npvgd", "trial_number": 0, "trial_result": "success", "result_value_type": "double", "result_value": 98.78, "operation" : "EXP_TRIAL_RESULT", "tunable_name" : "cpuRequest"}'
	[valid-experiment-result]='{"experiment_name" : "petclinic-sample-2-75884c5549-npvgd", "trial_number": 0, "trial_result": "success", "result_value_type": "double", "result_value": 98.78, "operation" : "EXP_TRIAL_RESULT"}'
	[valid-different-result]='{"experiment_name" : "petclinic-sample-2-75884c5549-npvgd", "trial_number": 0, "trial_result": "success", "result_value_type": "double", "result_value": 89.78, "operation" : "EXP_TRIAL_RESULT"}')


declare -A hpo_exp_result_error_messages
hpo_exp_result_error_messages=(
[empty-name]="Parameters cannot be empty or null"
[no-name]="'experiment_name' is a required property"
[null-name]="Parameters cannot be empty or null"

[invalid-trial-number]="Requested trial exceeds the completed trial limit"
[no-trial-number]="'trial_number' is a required property"
[null-trial-number]="Parameters cannot be empty or null"

[invalid-trial-result]="Trial result status is invalid"
[empty-trial-result]="Trial result status is invalid"
[no-trial-result]="'trial_result' is a required property"
[null-trial-result]="Parameters cannot be empty or null"

[invalid-result-value-type]="Unsupported value type"
[empty-result-value-type]="Unsupported value type"
[no-result-value-type]="'result_value_type' is a required property"
[null-result-value-type]="Parameters cannot be empty or null"

[invalid-result-value]="result_value cannot be negative"
[no-result-value]="'result_value' is a required property"
[null-result-value]="Parameters cannot be empty or null"

[invalid-operation]="Invalid Operation value"
[empty-operation]="Parameters cannot be empty or null"
[no-operation]="'operation' is a required property"
[null-operation]="Parameters cannot be empty or null"

[additional-field]="Additional properties are not allowed"
[valid-experiment-result]="Starting Experiment"

)

