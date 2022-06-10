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

import threading
import json
from bayes_optuna import optuna_hpo
from exceptions import ExperimentNotFoundError


class HpoService:
    """
    HpoService manages all running experiments, including starting experiments, updating trial results and returning
    optimized configurations
    """

    def __init__(self):
        self.experiments = {}
        self.expStateCond = threading.Condition()  #We might weant a more fine grained locking mechanism, e.g.readerwriterlock

    def newExperiment(self, id_, experiment_name, total_trials, parallel_trials, direction, hpo_algo_impl,
                      objective_function, tunables, value_type):
        if self.containsExperiment(experiment_name):
            print("Experiment already exists")
            return

        try:
            self.expStateCond.acquire()
            self.experiments[experiment_name] = optuna_hpo.HpoExperiment(experiment_name, total_trials, parallel_trials,
                                                                     direction, hpo_algo_impl, id_, objective_function,
                                                                     tunables, value_type)
        finally:
            self.expStateCond.release()

    def stopExperiment(self, experiment_name):
        try:
            self.expStateCond.acquire()
            if self.containsExperiment(experiment_name):
                experiment: optuna_hpo.HpoExperiment = self.experiments[experiment_name]
                del self.experiments[experiment_name]
                experiment.stop()
        finally:
            self.expStateCond.release()

    def startExperiment(self, name):
        try:
            self.expStateCond.acquire()
            experiment: optuna_hpo.HpoExperiment = self.experiments.get(name)
        finally:
            self.expStateCond.release()

        started: threading.Condition = experiment.start()
        try:
            started.acquire()
            value = started.wait(10)  # wait with timeout of 10s
        finally:
            started.release()

        if not value:
            print("Starting experiment timed  out!")

    def containsExperiment(self, name):
        result = False
        try:
            self.expStateCond.acquire()
            if self.experiments is not None or self.experiments:
                result = name in self.experiments.keys()
        finally:
            self.expStateCond.release()

        return result

    def doesNotContainExperiment(self, name):
        return not self.containsExperiment(name)

    def getExperimentsList(self):
        try:
            self.expStateCond.acquire()
            expKeys = self.experiments.keys()
        finally:
            self.expStateCond.release()

        return expKeys

    def getExperiment(self, name) -> optuna_hpo.HpoExperiment:
        if self.doesNotContainExperiment(name):
            print("Experiment " + name + " does not exist")
            raise ExperimentNotFoundError
        try:
            self.expStateCond.acquire()
            expname = self.experiments.get(name)
        finally:
            self.expStateCond.release()

        return expname

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
                trialConfig = json.dumps(experiment.trialDetails.trial_json_object)
            finally:
                experiment.resultsAvailableCond.release()
            return trialConfig

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

    def get_recommended_config(self, id_):
        experiment: optuna_hpo.HpoExperiment = self.getExperiment(id_)
        try:
            experiment.resultsAvailableCond.acquire()
            recommendedConfig = experiment.recommended_config
        finally:
            experiment.resultsAvailableCond.release()

        return recommendedConfig


instance: HpoService = HpoService()
