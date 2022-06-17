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
    ALGOS_SUPPORTED = ("optuna_tpe", "optuna_tpe_multivariate", "optuna_skopt")


class HPOErrorConstants:
    INVALID_OPERATION = "Invalid Operation value"
    INVALID_CONTENT_TYPE = "Invalid content type. Should be application/json"
    NOT_FOUND = "Could not be find requested resource. Please check the URL!"

    DIRECTION_NOT_SUPPORTED = "Direction not supported!"
    VALUE_TYPE_NOT_SUPPORTED = "Unsupported value type!"
    VALUE_MISSING = " cannot be empty!"
    HPO_ALGO_NOT_SUPPORTED = "HPO algorithm not supported!"

    MISSING_PARAMETERS = "Missing required parameters!"
    EXPERIMENT_NOT_FOUND = "Experiment not found!"
    EXPERIMENT_EXISTS = "Experiment already exists!"
    NEGATIVE_TRIAL = "Trial number cannot be negative!"
    TRIAL_EXCEEDED = "Requested trial exceeds the completed trial limit!"
    NON_INTEGER_VALUE = "Only Integer value is allowed!"
    VALUE_TYPE_MISMATCH = "Value and value type do not match."


class HPOMessages:
    RESULT_STATUS = "Result posted successfully"
    TRIAL_COMPLETION_STATUS = "Trials completed for experiment: "
