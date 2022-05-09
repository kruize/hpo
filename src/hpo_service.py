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
import sys
import threading
import json
import csv
import itertools
from bayes_optuna import optuna_hpo
from exceptions import ExperimentNotFoundError

rank_value = 1


class HpoService:
    """
    HpoService manages all running experiments, including starting experiments, updating trial results and returning optimized configurations
    """

    def __init__(self):
        self.experiments = {}

    def newExperiment(self, id_, experiment_name, total_trials, parallel_trials, direction, hpo_algo_impl, objective_function, tunables, value_type):
        if self.containsExperiment(experiment_name):
            print("Experiment already exists")
            return

        self.experiments[experiment_name] = optuna_hpo.HpoExperiment(experiment_name, total_trials, parallel_trials, direction, hpo_algo_impl, id_, objective_function, tunables, value_type)


    def startExperiment(self, name):
        experiment: optuna_hpo.HpoExperiment = self.experiments.get(name)
        started: threading.Condition = experiment.start()
        try:
            started.acquire()
            value = started.wait(10) #wait with timeout of 10s
        finally:
            started.release()

        if not value:
            print("Starting experiment timed  out!")

    def containsExperiment(self, name):
        if self.experiments is None or not self.experiments :
            return False
        return name in self.experiments.keys()

    def doesNotContainExperiment(self, name):
        return not self.containsExperiment(name)

    def getExperimentsList(self):
        return self.experiments.keys()

    def getExperiment(self, name) -> optuna_hpo.HpoExperiment:
        if self.doesNotContainExperiment(name):
            print("Experiment " + name + " does not exist")
            raise ExperimentNotFoundError

        return self.experiments.get(name)


    def get_trial_number(self, name):

        experiment: optuna_hpo.HpoExperiment = self.getExperiment(name)
        """Return the trial number."""
        if experiment.hpo_algo_impl in ("optuna_tpe", "optuna_tpe_multivariate", "optuna_skopt"):
            try:
                experiment.resultsAvailableCond.acquire()
                trial_number = experiment.trialDetails.trial_number
            finally:
                experiment.resultsAvailableCond.release()
        return trial_number


    def get_trial_json_object(self, id_):
        experiment: optuna_hpo.HpoExperiment = self.getExperiment(id_)
        """Return the trial json object."""
        if experiment.hpo_algo_impl in ("optuna_tpe", "optuna_tpe_multivariate", "optuna_skopt"):
            try:
                experiment.resultsAvailableCond.acquire()
                # call method to write it in CSV
                self.writeToCSV(experiment)
                return json.dumps(experiment.trialDetails.trial_json_object)
            finally:
                experiment.resultsAvailableCond.release()


    def set_result(self, id_, trial_result, result_value_type, result_value):
        experiment: optuna_hpo.HpoExperiment = self.getExperiment(id_)
        """Set the details of a trial."""
        if experiment.hpo_algo_impl in ("optuna_tpe", "optuna_tpe_multivariate", "optuna_skopt"):
            try:
                experiment.resultsAvailableCond.acquire()
                experiment.trialDetails.trial_result = trial_result
                experiment.trialDetails.result_value_type = result_value_type
                experiment.trialDetails.result_value = result_value
                experiment.resultsAvailableCond.notify()
            finally:
                experiment.resultsAvailableCond.release()

    # TODO: Need to update this
    #  add trial results in a CSV file
    def writeToCSV(self, experiment):

        global rank_value
        trial_json_object = experiment.trialDetails.trial_json_object
        trial_number = experiment.trialDetails.trial_number
        experiment_name = experiment.experiment_name

        # open a file or append existing one for writing
        file_name = "src/trial_data/" + experiment_name + "_trial_configs.csv"
        config_file = open(file_name, 'a', newline='')
        csv_writer = csv.writer(config_file)

        header = ["Rank"]
        values = [rank_value]
        for trial in trial_json_object:
            if trial_number == 0:
                header.append(trial["tunable_name"])
            values.append(trial["tunable_value"])

        # Writing data of CSV file
        if trial_number == 0:
            csv_writer.writerow(header)
        csv_writer.writerow(values)

        config_file.close()
        rank_value += 1

    def getConfigs(self, trial_number, experiment):

        experiment_name = experiment.experiment_name
        configs_json_array = []
        csv_file_path = "src/trial_data/" + experiment_name + "_trial_configs.csv"
        try:
            csv_file = open(csv_file_path, 'r')
        except FileNotFoundError:
            print(f"File {csv_file_path} not found.  Aborting")
            raise FileNotFoundError
        else:
            # read csv file
            with csv_file:
                # load csv file data using csv library's dictionary reader
                csv_reader = csv.DictReader(csv_file)
                # convert each csv row into python dict
                for row in itertools.islice(csv_reader, trial_number):
                    # add this python dict to json array
                    configs_json_array.append(row)

                # convert python jsonArray to JSON String and write to file
                configs_json = json.dumps(configs_json_array, indent=4)
            print("Best configs : \n", configs_json)
            return configs_json


instance: HpoService = HpoService();
