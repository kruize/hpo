"""
Copyright (c) 2020, 2022 Red Hat, IBM Corporation and others.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
"""


def get_all_tunables(search_space_json):
    """
    Query API for the experiment_name, direction, hpo_algo_impl, id_, objective_function, tunables and
    value_type, and return them.

    Parameters: search_space_json (json array): A JSON array containing the input search space to hyperparameter
    optimization module.

    Returns:
        experiment_name (str): The name of the application that is being optimized.
        direction (str): Direction of optimization, minimize or maximize.
        hpo_algo_impl (str): Hyperparameter optimization library to perform Bayesian Optimization.
        id_ (str): The experiment id of the application that is being optimized.
        objective_function (str): The objective function that is being optimized.
        tunables (list): A list containing the details of each tunable in a dictionary format.
        value_type (string): Value type of the objective function.
    """
    id_ = search_space_json["experiment_id"]
    experiment_name = search_space_json["experiment_name"]
    total_trials = search_space_json["total_trials"]
    parallel_trials = search_space_json["parallel_trials"]
    objective_function = search_space_json["objective_function"]
    value_type = search_space_json["value_type"]
    direction = search_space_json["direction"]
    hpo_algo_impl = search_space_json["hpo_algo_impl"]
    tunables = search_space_json["tunables"]
    return experiment_name, total_trials, parallel_trials, direction, hpo_algo_impl, id_, objective_function, tunables, value_type
