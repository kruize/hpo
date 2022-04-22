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
import requests
import os
from urllib.parse import urlparse, parse_qs

from json_validate import validate_trial_generate_json
from tunables import get_all_tunables
from logger import get_logger

import hpo_service

logger = get_logger(__name__)

n_trials = 10
n_jobs = 1
autotune_object_ids = {}
search_space_json = []

api_endpoint = "/experiment_trials"
host_name="0.0.0.0"
server_port = 8085

fileDir = os.path.dirname(os.path.realpath('index.html'))
filename = os.path.join(fileDir, 'index.html')
welcome_page=filename


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

            if ("experiment_id" in query and "trial_number" in query and hpo_service.instance.containsExperiment(query["experiment_id"][0]) and
                    query["trial_number"][0] == str(hpo_service.instance.get_trial_number(query["experiment_id"][0]))):
                data = hpo_service.instance.get_trial_json_object(query["experiment_id"][0])
                self._set_response(200, data)            
            else:
                self._set_response(404, "-1")
        elif (self.path == "/"):
                data = self.getHomeScreen()
                self._set_response(200, data)
        else:
            self._set_response(403, "-1")

    def getHomeScreen(self):
        fin = open(welcome_page)
        content = fin.read()
        fin.close()
        return content

    def handle_generate_new_operation(self, json_object):
        """Process EXP_TRIAL_GENERATE_NEW operation."""
        is_valid_json_object = validate_trial_generate_json(json_object)

        if is_valid_json_object and hpo_service.instance.doesNotContainExperiment(json_object["search_space"]["experiment_id"]):
            search_space_json = json_object["search_space"]
            get_search_create_study(search_space_json, json_object["operation"])
            trial_number = hpo_service.instance.get_trial_number(json_object["search_space"]["experiment_id"])
            self._set_response(200, str(trial_number))
        else:
            self._set_response(400, "-1")

    def handle_generate_subsequent_operation(self, json_object):
        """Process EXP_TRIAL_GENERATE_SUBSEQUENT operation."""
        is_valid_json_object = validate_trial_generate_json(json_object)
        experiment_id = json_object["experiment_id"]
        if is_valid_json_object and hpo_service.instance.containsExperiment(experiment_id):
            trial_number = hpo_service.instance.get_trial_number(experiment_id)
            self._set_response(200, str(trial_number))
        else:
            self._set_response(400, "-1")

    def handle_result_operation(self, json_object):
        """Process EXP_TRIAL_RESULT operation."""
        if (hpo_service.instance.containsExperiment(json_object["experiment_id"]) and
                json_object["trial_number"] == hpo_service.instance.get_trial_number(json_object["experiment_id"])):
            hpo_service.instance.set_result(json_object["experiment_id"], json_object["trial_result"], json_object["result_value_type"],
                       json_object["result_value"])
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
        if (not parallel_trials):
            parallel_trials = n_jobs
        elif parallel_trials != 1:
            raise Exception("Parallel Trials value should be '1' only!")

        logger.info("Total Trials = "+str(total_trials))
        logger.info("Parallel Trials = "+str(parallel_trials))
        
        if hpo_algo_impl in ("optuna_tpe", "optuna_tpe_multivariate", "optuna_skopt"):
            hpo_service.instance.newExperiment(id_, experiment_name, total_trials, parallel_trials, direction, hpo_algo_impl, objective_function,
                                                 tunables, value_type)
            print("Starting Experiment: " + experiment_name)
            hpo_service.instance.startExperiment(id_)


# TODO: Update below API
def get_function_variables(url):
    """Perform a GET request and get the function variables"""
    r = requests.get(url)
    r.raise_for_status()
    function_variable_json = r.json()
    return function_variable_json


def main():    
    server = HTTPServer((host_name, server_port), HTTPRequestHandler)
    logger.info("Access server at http://%s:%s" % ("localhost", server_port))
    server.serve_forever()

if __name__ == '__main__':
    main()
