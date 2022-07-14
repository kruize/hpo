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
from json import JSONDecodeError
from urllib.parse import urlparse, parse_qs

from json_validate import validate_trial_generate_json
from tunables import get_all_tunables
from logger import get_logger
from utils import HPOErrorConstants, HPOSupportedTypes, HPOMessages

import hpo_service

logger = get_logger(__name__)
autotune_object_ids = {}
search_space_json = []

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
		if re.search(HPOSupportedTypes.API_ENDPOINT + "$", self.path):
			content_type, params = cgi.parse_header(self.headers.get('content-type'))
			if content_type == HPOSupportedTypes.CONTENT_TYPE:
				length = int(self.headers.get('content-length'))
				str_object = self.rfile.read(length).decode('utf8')
				try:
					json_object = json.loads(str_object)
				except JSONDecodeError as jde:
					logger.error(jde.msg)
					self._set_response(400, HPOErrorConstants.JSON_STRUCTURE_ERROR + jde.msg)
					return

				# validate JSON Object received
				if "operation" not in json_object:
					errorMsg = "'operation'" + HPOErrorConstants.REQUIRED_PROPERTY
					logger.error(errorMsg)
					self._set_response(400, errorMsg)
					return
				# further, validate the JSON structure and proceed accordingly
				isInvalid = validate_trial_generate_json(json_object)
				if isInvalid:
					logger.error(isInvalid)
					self._set_response(400, isInvalid)
				else:
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
		if re.search(HPOSupportedTypes.API_ENDPOINT, self.path):
			query = parse_qs(urlparse(self.path).query)
			if "experiment_name" not in query or "trial_number" not in query:
				error_msg = HPOErrorConstants.MISSING_PARAMETERS
				logger.error(error_msg)
				self._set_response(400, error_msg)
				return
			if self.validate_experiment_name(query["experiment_name"][0]):
				return

			error_msg = self.validate_trialNumber(query["experiment_name"][0], query["trial_number"][0])
			if error_msg:
				self._set_response(400, error_msg)
			else:
				logger.info("Experiment_Name = " + str(
					hpo_service.instance.getExperiment(query["experiment_name"][0]).experiment_name))
				logger.info("Trial_Number = " + str(
					hpo_service.instance.getExperiment(query["experiment_name"][0]).trialDetails.trial_number))
				data = hpo_service.instance.get_trial_json_object(query["experiment_name"][0])
				self._set_response(200, data)
		elif self.path == "/health":
			if self.getHomeScreen():
				self._set_response(200, 'OK')
			else:
				self._set_response(503, 'Service Unavailable')
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
		if existingExperiment:
			logger.error(HPOErrorConstants.EXPERIMENT_EXISTS)
			self._set_response(400, HPOErrorConstants.EXPERIMENT_EXISTS)
		else:
			search_space_json = json_object["search_space"]
			search_space = self.setDefaults(search_space_json)
			if not search_space:
				self._set_response(400, HPOErrorConstants.PARALLEL_TRIALS_ERROR)
			else:
				response = get_search_create_study(search_space, json_object["operation"])
				if response:
					self._set_response(400, response)
					return
				trial_number = hpo_service.instance.get_trial_number(json_object["search_space"]["experiment_name"])
				self._set_response(200, str(trial_number))

	def handle_generate_subsequent_operation(self, json_object):
		"""Process EXP_TRIAL_GENERATE_SUBSEQUENT operation."""
		experiment_name = json_object["experiment_name"]
		existingExperiment = hpo_service.instance.containsExperiment(experiment_name)
		if not existingExperiment:
			logger.error(HPOErrorConstants.EXPERIMENT_NOT_FOUND)
			self._set_response(404, HPOErrorConstants.EXPERIMENT_NOT_FOUND)
			return
		else:
			trial_number = hpo_service.instance.get_trial_number(experiment_name)
			if trial_number == -1:
				logger.error(HPOMessages.TRIAL_COMPLETION_STATUS + experiment_name)
				self._set_response(400, HPOMessages.TRIAL_COMPLETION_STATUS + experiment_name)
			else:
				self._set_response(200, str(trial_number))

	def handle_result_operation(self, json_object):
		"""Process EXP_TRIAL_RESULT operation."""
		if self.validate_experiment_name(json_object["experiment_name"]):
			return

		trialValidationError = self.validate_trialNumber(json_object["experiment_name"],
																		str(json_object["trial_number"]))
		resultDataValidationError = self.validate_result_data(json_object["trial_result"],
															  json_object["result_value_type"],
															  json_object["result_value"])
		if trialValidationError:
			self._set_response(400, trialValidationError)
			logger.error(trialValidationError)
		elif resultDataValidationError:
			self._set_response(400, resultDataValidationError)
			logger.error(resultDataValidationError)
		else:
			hpo_service.instance.set_result(json_object["experiment_name"], json_object["trial_result"],
											json_object["result_value_type"], json_object["result_value"])
			self._set_response(200, HPOMessages.RESULT_STATUS)

	def validate_experiment_name(self, experiment_name):
		error_msg = ""
		if not experiment_name or experiment_name.isspace() or experiment_name == "null":
			error_msg = "Parameters" + HPOErrorConstants.VALUE_MISSING
			self._set_response(400, error_msg)
			logger.error(error_msg)
		# validate the existence of experiment name and trial number
		elif not hpo_service.instance.containsExperiment(experiment_name):
			error_msg = HPOErrorConstants.EXPERIMENT_NOT_FOUND
			self._set_response(404, error_msg)
			logger.error(error_msg)

		return error_msg

	def validate_trialNumber(self, experiment_name, trial_number):
		errorMsg = ""
		if not trial_number == str(hpo_service.instance.get_trial_number(experiment_name)):
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
		elif float(result_value) < 0:
			errorMsg = HPOErrorConstants.NEGATIVE_VALUE

		return errorMsg

	def handle_stop_operation(self, json_object):
		"""Process EXP_STOP operation."""
		if hpo_service.instance.containsExperiment(json_object["experiment_name"]):
			hpo_service.instance.stopExperiment(json_object["experiment_name"])
			self._set_response(200, HPOMessages.EXPERIMENT_STOP)
		else:
			self._set_response(404, HPOErrorConstants.EXPERIMENT_NOT_FOUND)

	def setDefaults(self, search_space):
		if "hpo_algo_impl" not in search_space:
			search_space["hpo_algo_impl"] = HPOSupportedTypes.HPO_ALGO
		if "value_type" not in search_space:
			search_space["value_type"] = HPOSupportedTypes.VALUE_TYPE
		if "parallel_trials" not in search_space:
			search_space["parallel_trials"] = HPOSupportedTypes.N_JOBS
		elif search_space["parallel_trials"] != 1:
			logger.error(HPOErrorConstants.PARALLEL_TRIALS_ERROR)
			return

		return search_space


def get_search_create_study(search_space_json, operation):
	if operation == "EXP_TRIAL_GENERATE_NEW":
		experiment_name, total_trials, parallel_trials, direction, hpo_algo_impl, id_, objective_function, tunables, \
		value_type = get_all_tunables(search_space_json)

		logger.info("Total Trials = " + str(total_trials))
		logger.info("Parallel Trials = " + str(parallel_trials))

		hpo_service.instance.newExperiment(id_, experiment_name, total_trials, parallel_trials, direction,
										   hpo_algo_impl, objective_function, tunables, value_type)
		logger.info("Starting Experiment: " + experiment_name)
		# check response, it will have error message if the experiment timed out else nothing will be returned
		response = hpo_service.instance.startExperiment(experiment_name)
		if response:
			return response


def main():
	server = HTTPServer((HPOSupportedTypes.SERVER_HOSTNAME, HPOSupportedTypes.SERVER_PORT), HTTPRequestHandler)
	logger.info("Access REST Service at http://%s:%s" % ("localhost", HPOSupportedTypes.SERVER_PORT))
	server.serve_forever()


if __name__ == '__main__':
	main()
