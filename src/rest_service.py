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
from http.server import BaseHTTPRequestHandler, HTTPServer
import re
import cgi
import json
import requests
import os
from urllib.parse import urlparse, parse_qs

from json_validate import validate_trial_generate_json
from tunables import get_all_tunables
from logger import get_logger

import hpo_service

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, BASE_DIR)
from db import pg_connection, tables, operations

logger = get_logger(__name__)

n_trials = 10
n_jobs = 1
autotune_object_ids = {}
search_space_json = []

api_endpoint = "/experiment_trials"
api_endpoint_recommendation = "/recommendations"
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
                # TODO: validate structure of json_object for each operation
                if json_object["operation"] == "EXP_TRIAL_GENERATE_NEW":
                    self.handle_generate_new_operation(json_object)
                elif json_object["operation"] == "EXP_TRIAL_GENERATE_SUBSEQUENT":
                    self.handle_generate_subsequent_operation(json_object)
                elif json_object["operation"] == "EXP_TRIAL_RESULT":
                    self.handle_result_operation(json_object)
                else:
                    self._set_response(400, "-1")
            else:
                self._set_response(400, "-1")
        else:
            self._set_response(403, "-1")

    def do_GET(self):
        """Serve a GET request."""
        if re.search(api_endpoint, self.path):
            query = parse_qs(urlparse(self.path).query)

            if ("experiment_name" in query and "trial_number" in query and hpo_service.instance.containsExperiment(
                    query["experiment_name"][0]) and
                    query["trial_number"][0] == str(
                        hpo_service.instance.get_trial_number(query["experiment_name"][0]))):
                logger.info("Experiment_Name = " + str(
                    hpo_service.instance.getExperiment(query["experiment_name"][0]).experiment_name))
                logger.info("Trial_Number = " + str(
                    hpo_service.instance.getExperiment(query["experiment_name"][0]).trialDetails.trial_number))
                data = hpo_service.instance.get_trial_json_object(query["experiment_name"][0])
                self._set_response(200, data)
            else:
                self._set_response(404, "Invalid URL or missing required parameters!")
        elif re.search(api_endpoint_recommendation, self.path):
            query = parse_qs(urlparse(self.path).query)
            # check if the request contains 'experiment_name' and 'trials'
            if "experiment_name" in query and "trials" in query:
                self.getRecommendations(query)
            else:
                self._set_response(404, "Invalid URL or missing required parameters!")
        elif self.path == "/":
            data = self.getHomeScreen()
            self._set_response(200, data)
        else:
            self._set_response(404, "Error! The requested resource could not be found.")

    def getRecommendations(self, query):
        experiment_name = str(query["experiment_name"][0]).replace("-", "_")
        trial_result_needed = int(query["trials"][0])
        if trial_result_needed < 0:
            data = "Invalid Trials value"
            logger.error(data)
            self._set_response(403, data)
            return

        # call database operations function to fetch the configs
        db_response = operations.get_recommended_configs(trial_result_needed, experiment_name)

        # check if the response is valid JSON else return the corresponding error response
        try:
            json.loads(db_response)
            self._set_response(200, db_response)
        except ValueError:
            logger.error(db_response)
            self._set_response(403, "-1")

    def getHomeScreen(self):
        fin = open(welcome_page)
        content = fin.read()
        fin.close()
        return content

    def handle_generate_new_operation(self, json_object):
        """Process EXP_TRIAL_GENERATE_NEW operation."""
        is_valid_json_object = validate_trial_generate_json(json_object)
        experiment_name = json_object["search_space"]["experiment_name"]
        if is_valid_json_object and hpo_service.instance.doesNotContainExperiment(experiment_name):
            search_space_json = json_object["search_space"]
            if str(search_space_json["experiment_name"]).isspace() or not str(search_space_json["experiment_name"]):
                self._set_response(400, "-1")
                return
            obj_function = search_space_json["objective_function"]

            # call db function to open a connection and insert data in experiments table
            tables.create_tables()
            response = operations.insert_experiment_data(experiment_name, search_space_json, obj_function)

            if response:
                self._set_response(403, "-1")
                return

            get_search_create_study(search_space_json, json_object["operation"])
            trial_number = hpo_service.instance.get_trial_number(json_object["search_space"]["experiment_name"])
            self._set_response(200, str(trial_number))
        else:
            self._set_response(400, "-1")

    def handle_generate_subsequent_operation(self, json_object):
        """Process EXP_TRIAL_GENERATE_SUBSEQUENT operation."""
        is_valid_json_object = validate_trial_generate_json(json_object)
        experiment_name = json_object["experiment_name"]
        if is_valid_json_object and hpo_service.instance.containsExperiment(experiment_name):
            trial_number = hpo_service.instance.get_trial_number(experiment_name)
            if trial_number == -1:
                self._set_response(400, "Trials completed for experiment: " + experiment_name)
            else:
                self._set_response(200, str(trial_number))
        else:
            self._set_response(400, "-1")

    def handle_result_operation(self, json_object):
        """Process EXP_TRIAL_RESULT operation."""
        if (hpo_service.instance.containsExperiment(json_object["experiment_name"]) and
                json_object["trial_number"] == hpo_service.instance.get_trial_number(json_object["experiment_name"])):
            hpo_service.instance.set_result(json_object["experiment_name"], json_object["trial_result"],
                                            json_object["result_value_type"],
                                            json_object["result_value"])
            trial_json = hpo_service.instance.get_trial_json_object(json_object["experiment_name"])

            # call db operations function to store experiment details after each trial
            response = operations.insert_trial_details(json_object, trial_json)

            if response:
                self._set_response(403, "-1")
                return

            self._set_response(200, "0")
        else:
            self._set_response(400, "-1")


def get_search_create_study(search_space_json, operation):
    # TODO: validate structure of search_space_json

    if operation == "EXP_TRIAL_GENERATE_NEW":
        if "parallel_trials" not in search_space_json:
            search_space_json["parallel_trials"] = n_jobs
        experiment_name, total_trials, parallel_trials, direction, hpo_algo_impl, id_, objective_function, tunables, value_type = get_all_tunables(
            search_space_json)
        if not parallel_trials:
            parallel_trials = n_jobs
        elif parallel_trials != 1:
            raise Exception("Parallel Trials value should be '1' only!")

        logger.info("Total Trials = " + str(total_trials))
        logger.info("Parallel Trials = " + str(parallel_trials))

        if hpo_algo_impl in ("optuna_tpe", "optuna_tpe_multivariate", "optuna_skopt"):
            hpo_service.instance.newExperiment(id_, experiment_name, total_trials, parallel_trials, direction,
                                               hpo_algo_impl, objective_function,
                                               tunables, value_type)
            print("Starting Experiment: " + experiment_name)
            hpo_service.instance.startExperiment(experiment_name)


def get_search_space(id_, url):
    """Perform a GET request and return the search space json."""
    params = {"id": id_}
    r = requests.get(url, params)
    r.raise_for_status()
    search_space_json = r.json()
    return search_space_json


def main():
    server = HTTPServer((host_name, server_port), HTTPRequestHandler)

    # check if DB is running
    conn = pg_connection.connect_to_pg()
    if conn is None:
        logger.error("Database is not Running. Exiting...")
        sys.exit()

    logger.info("Access server at http://%s:%s" % ("localhost", server_port))
    server.serve_forever()


if __name__ == '__main__':
    main()
