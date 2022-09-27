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
import os

import optuna
import threading
import json

from logger import get_logger

logger = get_logger(__name__)

trials = []


class TrialDetails:
    """
    A class containing the details of a trial such as trial number, tunable values suggested by Optuna, status of the
    experiment and the objective function value type and value.
    """
    trial_number: int
    trial_json_object: dict
    trial_result_received: int
    trial_result: str
    result_value_type: str
    result_value: float

    def __init__(self, trial_number=-1,trial_json_object = {},trial_result_received = -1,trial_result = "",
                 result_value_type = "",result_value = 0):
        self.trial_number = trial_number
        self.trial_json_object = trial_json_object
        self.trial_result_received = trial_result_received
        self.trial_result = trial_result
        self.result_value_type = result_value_type
        self.result_value = result_value


class HpoExperiment:
    """
    HpoExperiment contains the details of a Running experiment.
    """
    thread: threading.Thread
    experiment_name: str
    total_trials: int
    parallel_trials: int
    direction: str
    hpo_algo_impl: str
    id_: str
    objective_function: str
    tunables: str
    value_type: str
    trialDetails: TrialDetails
    resultsAvailableCond: threading.Condition
    experimentStartedCond: threading.Condition
    isRunning = True
    started = False
    # recommended_config (json): A JSON containing the recommended config.
    recommended_config = {}

    def __init__(self, experiment_name, total_trials, parallel_trials, direction, hpo_algo_impl, id_,
                 objective_function, tunables, value_type, trialDetails):
        self.experiment_name = experiment_name
        self.total_trials = total_trials
        self.parallel_trials = parallel_trials
        self.direction = direction
        self.hpo_algo_impl = hpo_algo_impl
        self.id_ = id_
        self.objective_function = objective_function
        self.tunables = tunables
        self.value_type = value_type
        self.trialDetails = trialDetails
        self.resultsAvailableCond = threading.Condition()
        self.experimentStartedCond = threading.Condition()
        self.thread = threading.Thread(target=self.recommend)

    def start(self) -> threading.Condition:
        try:
            self.experimentStartedCond.acquire()
            self.thread.daemon = True
            self.thread.start()
        finally:
            self.experimentStartedCond.release()
        return self.experimentStartedCond

    def hasStarted(self) -> bool:
        started = False
        try:
            self.experimentStartedCond.acquire()
            started = self.started
        finally:
            self.experimentStartedCond.release()
        return started

    def notifyStarted(self):
        # notify hpo_service.startExperiment() that experiment is ready to accept results
        if not self.hasStarted():
            try:
                self.experimentStartedCond.acquire()
                self.started = True
                self.experimentStartedCond.notify()
            finally:
                self.experimentStartedCond.release()

    def perform_experiment(self):
        try:
            self.resultsAvailableCond.acquire()
            self.resultsAvailableCond.wait()
            if self.isRunning == False:
                raise Exception("Stopping experiment: {}".format(self.experiment_name))
            result_value = self.trialDetails.result_value
            trial_result = self.trialDetails.trial_result
        finally:
            self.resultsAvailableCond.release()
        return result_value, trial_result

    def recommend(self):
        """
        Perform Bayesian Optimization with Optuna using the appropriate sampler and recommend the best config.

        Parameters:
            experiment_name (str): The name of the application that is being optimized.
            direction (str): Direction of optimization, minimize or maximize.
            hpo_algo_impl (str): Hyperparameter optimization library to perform Bayesian Optimization.
            id_ (str): The id of the application that is being optimized.
            objective_function (str): The objective function that is being optimized.
            tunables (list): A list containing the details of each tunable in a dictionary format.
            value_type (string): Value type of the objective function.
        """
        # Set the logging level for the Optuna’s root logger
        optuna.logging.set_verbosity(optuna.logging.WARNING)
        # Propagate all of Optuna log outputs to the root logger
        optuna.logging.enable_propagation()
        # Disable the default handler of the Optuna’s root logger
        optuna.logging.disable_default_handler()

        # Choose a sampler based on the value of ml_algo_impl
        if self.hpo_algo_impl == "optuna_tpe":
            sampler = optuna.samplers.TPESampler()
        elif self.hpo_algo_impl == "optuna_tpe_multivariate":
            sampler = optuna.samplers.TPESampler(multivariate=True)
        elif self.hpo_algo_impl == "optuna_skopt":
            sampler = optuna.integration.SkoptSampler()

        # Create a study object
        try:
            study = optuna.create_study(direction=self.direction, sampler=sampler, study_name=self.experiment_name)

            # Execute an optimization by using an 'Objective' instance
            study.optimize(Objective(self), n_trials=self.total_trials, n_jobs=self.parallel_trials)

            self.trialDetails.trial_number = -1

            # Get the best parameter
            logger.info("BEST PARAMETER: " + str(study.best_params))
            # Get the best value
            logger.info("BEST VALUE: " + str(study.best_value))
            # Get the best trial
            logger.info("BEST TRIAL: " + str(study.best_trial))

            logger.debug("ALL TRIALS: " + str(trials))

            # Generate tunable importance
            self.generate_importance(study)

            # Generate plots
            self.generate_plots(study)

            try:
                self.resultsAvailableCond.acquire()
                optimal_value = {"objective_function": {
                    "name": self.objective_function,
                    "value": study.best_value,
                    "value_type": self.value_type
                }, "tunables": []}

                for tunable in self.tunables:
                    for key, value in study.best_params.items():
                        if key == tunable["name"]:
                            tunable_value = value
                    optimal_value["tunables"].append(
                        {
                            "name": tunable["name"],
                            "value": tunable_value,
                            "value_type": tunable["value_type"]
                        }
                    )

                self.recommended_config["id"] = self.id_
                self.recommended_config["experiment_name"] = self.experiment_name
                self.recommended_config["direction"] = self.direction
                self.recommended_config["optimal_value"] = optimal_value
            finally:
                self.resultsAvailableCond.release()

            logger.info("RECOMMENDED CONFIG: " + str(self.recommended_config))
        except:
            logger.warn("Experiment stopped: " + str(self.experiment_name))

    def stop(self):
        try:
            self.resultsAvailableCond.acquire()
            self.isRunning = False
            self.resultsAvailableCond.notify()
        finally:
            self.resultsAvailableCond.release()

    def generate_importance(self, study):
        try:
            importance = optuna.importance.get_param_importances(study)
            logger.info("TUNABLES IMPORTANCE: " + str(json.dumps(importance)))
        except ValueError:
            logger.warn("Cannot evaluate tunable importance with only a single trial")
        except RuntimeError:
            logger.warn("Encountered zero total variance to calculate tunable importance")
        except:
            logger.warn("Encountered issues calculating tunable importance")

    def generate_plots(self, study):
        # Generate different plots
        plots = ["tunable_importance", "optimization_history", "slice", "parallel_coordinate"]
        for plot_type in plots:
            try:
                dirName = "plots/" + self.experiment_name
                os.makedirs(dirName, exist_ok=True)
                plotsDir = os.path.dirname(os.path.realpath(dirName))

                if plot_type == "tunable_importance":
                    plot = optuna.visualization.plot_param_importances(study)
                    plotFile = plotsDir + "/" + self.experiment_name + "/tunable_importance.html"
                if plot_type == "optimization_history":
                    plot = optuna.visualization.plot_optimization_history(study)
                    plotFile = plotsDir + "/" + self.experiment_name + "/optimization_history.html"
                if plot_type == "slice":
                    plot = optuna.visualization.plot_slice(study)
                    plotFile = plotsDir + "/" + self.experiment_name + "/slice.html"
                if plot_type == "parallel_coordinate":
                    plot = optuna.visualization.plot_parallel_coordinate(study)
                    plotFile = plotsDir + "/" + self.experiment_name + "/parallel_coordinate.html"
                # Commenting out contour plots as it gets hung sometimes when there are lot of tunables for a 100 trial experiment
                #if plot_type == "contour":
                #plot = optuna.visualization.plot_contour(study)
                #plotFile = plotsDir + "/" + self.experiment_name + "/contour.html"

                func = open(plotFile, "w")
                func.write(plot.to_html())
                func.close()
                logger.info("ACCESS " + plot_type + " CHART AT <REST_SERVICE_URL>/plot?" + "experiment_name=" + self.experiment_name + "&type=" + plot_type)
            except:
                logger.warn("Issues creating" + plot_type + " html file")



class Objective(TrialDetails):
    """
    A class used to define search space and return the actual slo value.

    Parameters:
        tunables (list): A list containing the details of each tunable in a dictionary format.
    """

    def __init__(self, experiment: HpoExperiment):
        self.experiment: HpoExperiment = experiment
        self.tunables = experiment.tunables

    def __call__(self, trial):
        global trials

        experiment_tunables = []
        config = {}

        try:
            self.experiment.resultsAvailableCond.acquire()
            self.experiment.trialDetails.trial_number += 1
            self.experiment.trialDetails.trial_json_object = {}
            self.experiment.trialDetails.trial_result = ""
            self.experiment.trialDetails.result_value_type = ""
            self.experiment.trialDetails.result_value = 0
        finally:
            self.experiment.resultsAvailableCond.release()

        try:
            self.experiment.resultsAvailableCond.acquire()
            # Define search space
            for tunable in self.tunables:
                if tunable["value_type"].lower() == "double":
                    tunable_value = trial.suggest_discrete_uniform(
                        tunable["name"], tunable["lower_bound"], tunable["upper_bound"], tunable["step"]
                    )
                elif tunable["value_type"].lower() == "integer":
                    tunable_value = trial.suggest_int(
                        tunable["name"], tunable["lower_bound"], tunable["upper_bound"], tunable["step"]
                    )
                elif tunable["value_type"].lower() == "categorical":
                    tunable_value = trial.suggest_categorical(tunable["name"], tunable["choices"])

                experiment_tunables.append({"tunable_name": tunable["name"], "tunable_value": tunable_value})

            config["experiment_tunables"] = experiment_tunables

            logger.debug("Experiment tunables: " + str(experiment_tunables))
            self.experiment.trialDetails.trial_json_object = experiment_tunables
        finally:
            self.experiment.resultsAvailableCond.release()

        self.experiment.notifyStarted()

        actual_slo_value, experiment_status = self.experiment.perform_experiment()

        config["experiment_status"] = experiment_status

        trials.append(config)

        if experiment_status == "failure":
            raise optuna.TrialPruned()

        actual_slo_value = round(float(actual_slo_value), 2)
        return actual_slo_value
