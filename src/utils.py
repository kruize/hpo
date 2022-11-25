"""
Copyright (c) 2020, 2022 Red Hat, IBM Corporation and others.

Licensed under the Apache License, Version 2.0 (the "License")  
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
"""


class HPOSupportedTypes:
    DIRECTIONS_SUPPORTED = ("minimize", "maximize")
    VALUE_TYPES_SUPPORTED = ("double", "int", float)
    OPTUNA_ALGOS = ("optuna_tpe", "optuna_tpe_multivariate", "optuna_skopt")
    ALGOS_SUPPORTED = (OPTUNA_ALGOS)
    TRIAL_RESULT_STATUS = ("success", "failure", "error")

    # Default Values
    HPO_ALGO = "optuna_tpe"
    VALUE_TYPE = "double"
    N_JOBS = 1
    N_TRIALS = 10
    SERVER_HOSTNAME = "0.0.0.0"
    SERVER_PORT = 8085
    API_ENDPOINT = "/experiment_trials"
    CONTENT_TYPE = "application/json"


class HPOErrorConstants:
    INVALID_OPERATION = "Invalid Operation value!"
    INVALID_CONTENT_TYPE = "Invalid content type. Should be application/json!"
    NOT_FOUND = "Could not be find requested resource. Please check the URL!"
    REQUIRED_PROPERTY = " is a required property!"

    DIRECTION_NOT_SUPPORTED = "Direction not supported!"
    VALUE_TYPE_NOT_SUPPORTED = "Unsupported value type!"
    VALUE_MISSING = " cannot be empty or null!"
    HPO_ALGO_NOT_SUPPORTED = "HPO algorithm not supported!"
    INVALID_RESULT_STATUS = "Trial result status is invalid!"

    MISSING_PARAMETERS = "Missing required parameters!"
    EXPERIMENT_NOT_FOUND = "Experiment not found!"
    EXPERIMENT_EXISTS = "Experiment already exists!"
    EXPERIMENT_TIMED_OUT = "Starting experiment timed out!"

    INVALID_TOTAL_TRIALS = "Total trials should be greater than 0!"
    NEGATIVE_TRIAL = "Trial number cannot be negative!"
    TRIAL_EXCEEDED = "Requested trial exceeds the completed trial limit!"
    TRIAL_PRECEDES = "Requested trial is already completed!"
    NON_INTEGER_VALUE = "Only Integer value is allowed!"
    NEGATIVE_VALUE = "result_value cannot be negative!"
    VALUE_TYPE_MISMATCH = "Value and value type do not match!"
    PARALLEL_TRIALS_ERROR = "Parallel Trials value should be '1' only!"
    JSON_STRUCTURE_ERROR = "Invalid JSON structure: "

    JSON_NULL_VALUES = ("is not of type 'string'", "is not of type 'integer'", "is not of type 'number'")


class HPOMessages:
    RESULT_STATUS = "Result posted successfully!"
    TRIAL_COMPLETION_STATUS = "Trials completed for experiment: "
    EXPERIMENT_DELETE = "Experiment deleted!"
