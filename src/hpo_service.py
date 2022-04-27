import threading
import json
import csv
from bayes_optuna import optuna_hpo

class HpoService:
    """
    HpoService manages all running experiments, including starting experiments, updating trial results and returning optimized configurations
    """

    def __init__(self):
        self.experiments = {}

    def newExperiment(self, id_, experiment_name, total_trials, parallel_trials, direction, hpo_algo_impl, objective_function, tunables, value_type):
        if self.containsExperiment(id_):
            print("Experiment already exists")
            return

        self.experiments[id_] = optuna_hpo.HpoExperiment(experiment_name, total_trials, parallel_trials, direction, hpo_algo_impl, id_, objective_function, tunables, value_type)


    def startExperiment(self, id_):
        experiment: optuna_hpo.HpoExperiment = self.experiments.get(id_)
        started: threading.Condition = experiment.start()
        try:
            started.acquire()
            value = started.wait(10) #wait with timeout of 10s
        finally:
            started.release()

        if not value:
            print("Starting experiment timed  out!")

    def containsExperiment(self, id_):
        if self.experiments is None or not self.experiments :
            return False
        return id_ in self.experiments.keys()

    def doesNotContainExperiment(self, id_):
        return not self.containsExperiment(id_)

    def getExperiment(self, id_) -> optuna_hpo.HpoExperiment:
        if self.doesNotContainExperiment(id_):
            print("Experiment does not exist")
            return

        return self.experiments.get(id_)


    def get_trial_number(self, id_):

        experiment: optuna_hpo.HpoExperiment = self.getExperiment(id_)
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
                trial_json_object = json.dumps(experiment.trialDetails.trial_json_object)
            finally:
                experiment.resultsAvailableCond.release()
        return trial_json_object


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

    ## TODO: Need to update this
    #  add trial results in a CSV file
    def writeToCSV(self, trial_json_object, trial_number):

        # open a file for writing
        config_file = open('src/trial_data/trial_configs.csv', 'w', newline='')
        csv_writer = csv.writer(config_file)
        trial_json_object = json.loads(trial_json_object)
        for trial in trial_json_object:
            if trial_number == 0:
                header = trial.keys()
                csv_writer.writerow(header)
                trial_number += 1
            # Writing data of CSV file
            csv_writer.writerow(trial.values())

        config_file.close()

instance: HpoService = HpoService();