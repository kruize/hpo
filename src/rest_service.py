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

from http.server import BaseHTTPRequestHandler, HTTPServer
import re
import cgi
import json
import os
from urllib.parse import urlparse, parse_qs

from json_validate import validate_trial_generate_json
from tunables import get_all_tunables
from logger import get_logger
from utils import HPOErrorConstants, HPOSupportedTypes, HPOMessages

import hpo_service

logger = get_logger(__name__)

n_trials = 10
n_jobs = 1
autotune_object_ids = {}
search_space_json = []

api_endpoint = "/experiment_trials"
host_name = "0.0.0.0"
server_port = 8085

fileDir = os.path.dirname(os.path.realpath('index.html'))
filename = os.path.join(fileDir, 'index.html')
welcome_page = filename


class HTTPRequestHandler(BaseHTTPRequestHandler):
    """
    A class used to handle the HTTP requests that arrive at the server.

    The handler will parse the request and the headers, then call a method specific to the request type. The method name
    is constructed from the request. For example, for the request method GET, the do_GET() method will be called.
    """

    def _set_response(self, status_code, return_value):
        # TODO: add status_message
        self.send_response(status_code)
        self.send_header('Content-type', 'text/html')
        self.end_headers()
        self.wfile.write(return_value.encode('utf-8'))

    def do_POST(self):
        """Serve a POST request."""
        if re.search(api_endpoint + "$", self.path):
            content_type, params = cgi.parse_header(self.headers.get('content-type'))
            if content_type == 'application/json':
                length = int(self.headers.get('content-length'))
                str_object = self.rfile.read(length).decode('utf8')
                json_object = json.loads(str_object)

                if json_object["operation"] == "EXP_TRIAL_GENERATE_NEW":
                    self.handle_generate_new_operation(json_object)
                elif json_object["operation"] == "EXP_TRIAL_GENERATE_SUBSEQUENT":
                    self.handle_generate_subsequent_operation(json_object)
                elif json_object["operation"] == "EXP_TRIAL_RESULT":
                    self.handle_result_operation(json_object)
                elif json_object["operation"] == "EXP_STOP":
                    self.handle_stop_operation(json_object)
                else:
                    self._set_response(400, HPOErrorConstants.INVALID_OPERATION)
            else:
                self._set_response(400, HPOErrorConstants.INVALID_CONTENT_TYPE)
        else:
            self._set_response(404, HPOErrorConstants.NOT_FOUND)

    def do_GET(self):
        """Serve a GET request."""
        if re.search(api_endpoint, self.path):
            query = parse_qs(urlparse(self.path).query)
            if "experiment_name" not in query or "trial_number" not in query:
                errorMsg = HPOErrorConstants.MISSING_PARAMETERS
                logger.error(errorMsg)
                self._set_response(404, errorMsg)
                return
            # validate the existence of experiment name and trial number
            errorMsg = self.validate_experimentName_trialNumber(query["experiment_name"][0], query["trial_number"][0])
            if errorMsg:
                self._set_response(404, errorMsg)
            else:
                logger.info("Experiment_Name = " + str(
                    hpo_service.instance.getExperiment(query["experiment_name"][0]).experiment_name))
                logger.info("Trial_Number = " + str(
                    hpo_service.instance.getExperiment(query["experiment_name"][0]).trialDetails.trial_number))
                data = hpo_service.instance.get_trial_json_object(query["experiment_name"][0])
                self._set_response(200, data)
        elif self.path == "/":
            data = self.getHomeScreen()
            self._set_response(200, data)
        else:
            self._set_response(404, HPOErrorConstants.NOT_FOUND)

    def getHomeScreen(self):
        fin = open(welcome_page)
        content = fin.read()
        fin.close()
        return content

    def handle_generate_new_operation(self, json_object):
        """Process EXP_TRIAL_GENERATE_NEW operation."""
        existingExperiment = hpo_service.instance.containsExperiment(json_object["search_space"]["experiment_name"])
        validationStatus = validate_trial_generate_json(json_object)

        if validationStatus:
            logger.error(validationStatus)
            self._set_response(400, validationStatus)
        elif existingExperiment:
            logger.error(HPOErrorConstants.EXPERIMENT_EXISTS)
            self._set_response(400, HPOErrorConstants.EXPERIMENT_EXISTS)
        else:
            search_space_json = json_object["search_space"]
            get_search_create_study(search_space_json, json_object["operation"])
            trial_number = hpo_service.instance.get_trial_number(json_object["search_space"]["experiment_name"])
            self._set_response(200, str(trial_number))

    def handle_generate_subsequent_operation(self, json_object):
        """Process EXP_TRIAL_GENERATE_SUBSEQUENT operation."""
        experiment_name = json_object["experiment_name"]
        validationStatus = validate_trial_generate_json(json_object)
        if validationStatus:
            logger.error(validationStatus)
            self._set_response(400, validationStatus)
        elif hpo_service.instance.doesNotContainExperiment(experiment_name):
            logger.error(HPOErrorConstants.EXPERIMENT_NOT_FOUND)
            self._set_response(400, HPOErrorConstants.EXPERIMENT_NOT_FOUND)
        else:
            trial_number = hpo_service.instance.get_trial_number(experiment_name)
            if trial_number == -1:
                self._set_response(400, HPOMessages.TRIAL_COMPLETION_STATUS + experiment_name)
            else:
                self._set_response(200, str(trial_number))

    def handle_result_operation(self, json_object):
        """Process EXP_TRIAL_RESULT operation."""
        validationStatus = validate_trial_generate_json(json_object)
        if validationStatus:
            self._set_response(400, validationStatus)
            return
        experimentValidationError = self.validate_experimentName_trialNumber(json_object["experiment_name"],
                                                                             str(json_object["trial_number"]))
        resultDataValidationError = self.validate_result_data(json_object["trial_result"],
                                                              json_object["result_value_type"],
                                                              json_object["result_value"])
        if experimentValidationError:
            self._set_response(400, experimentValidationError)
            logger.error(experimentValidationError)
        elif resultDataValidationError:
            self._set_response(400, resultDataValidationError)
            logger.error(resultDataValidationError)
        else:
            hpo_service.instance.set_result(json_object["experiment_name"], json_object["trial_result"],
                                            json_object["result_value_type"], json_object["result_value"])
            self._set_response(200, HPOMessages.RESULT_STATUS)

    def validate_experimentName_trialNumber(self, experiment_name, trial_number):
        errorMsg = ""
        if not hpo_service.instance.containsExperiment(experiment_name):
            errorMsg = HPOErrorConstants.EXPERIMENT_NOT_FOUND
        elif not trial_number == str(hpo_service.instance.get_trial_number(experiment_name)):
            try:
                if int(trial_number) < 0:
                    errorMsg = HPOErrorConstants.NEGATIVE_TRIAL
                else:
                    errorMsg = HPOErrorConstants.TRIAL_EXCEEDED
            except ValueError:
                errorMsg = HPOErrorConstants.NON_INTEGER_VALUE

        return errorMsg

    def validate_result_data(self, trial_result, result_value_type, result_value):
        errorMsg = ""
        if trial_result not in HPOSupportedTypes.TRIAL_RESULT_STATUS:
            errorMsg = HPOErrorConstants.INVALID_RESULT_STATUS
        elif result_value_type not in HPOSupportedTypes.VALUE_TYPES_SUPPORTED:
            errorMsg = HPOErrorConstants.VALUE_TYPE_NOT_SUPPORTED
        elif not isinstance(result_value, (float, int)):
            errorMsg = HPOErrorConstants.VALUE_TYPE_MISMATCH

        return errorMsg

    def handle_stop_operation(self, json_object):
        """Process EXP_STOP operation."""
        if hpo_service.instance.containsExperiment(json_object["experiment_name"]):
            hpo_service.instance.stopExperiment(json_object["experiment_name"])
            self._set_response(200, HPOMessages.EXPERIMENT_STOP)
        else:
            self._set_response(404, HPOErrorConstants.EXPERIMENT_NOT_FOUND)


def get_search_create_study(search_space_json, operation):
    if operation == "EXP_TRIAL_GENERATE_NEW":
        if "parallel_trials" not in search_space_json:
            search_space_json["parallel_trials"] = n_jobs
        experiment_name, total_trials, parallel_trials, direction, hpo_algo_impl, id_, objective_function, tunables, \
            value_type = get_all_tunables(search_space_json)
        if not parallel_trials:
            parallel_trials = n_jobs
        elif parallel_trials != 1:
            raise Exception("Parallel Trials value should be '1' only!")

        logger.info("Total Trials = " + str(total_trials))
        logger.info("Parallel Trials = " + str(parallel_trials))

        if hpo_algo_impl in ("optuna_tpe", "optuna_tpe_multivariate", "optuna_skopt"):
            hpo_service.instance.newExperiment(id_, experiment_name, total_trials, parallel_trials, direction,
                                               hpo_algo_impl, objective_function,tunables, value_type)
            logger.info("Starting Experiment: " + experiment_name)
            hpo_service.instance.startExperiment(experiment_name)


def main():
    server = HTTPServer((host_name, server_port), HTTPRequestHandler)
    logger.info("Access server at http://%s:%s" % ("localhost", server_port))
    server.serve_forever()


if __name__ == '__main__':
    main()
