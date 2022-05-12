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

from concurrent import futures
from logger import get_logger

logger = get_logger(__name__)


import grpc
import json
from gRPC import hpo_pb2, hpo_pb2_grpc
import hpo_service
from google.protobuf.json_format import MessageToJson
from bayes_optuna.optuna_hpo import HpoExperiment
from gRPC.hpo_pb2 import NewExperimentsReply, RecommendedConfigReply, TunableConfig
from exceptions import ExperimentNotFoundError

host_name="0.0.0.0"
server_port = 50051

class HpoService(hpo_pb2_grpc.HpoServiceServicer):

    def NumberExperiments(self, request, context):
        return hpo_pb2.NumberExperimentsReply(count=len(hpo_service.instance.experiments))

    def ExperimentsList(self, request, context):
        experiments = hpo_service.instance.getExperimentsList()
        experimentsListreply = hpo_pb2.ExperimentsListReply()
        for experiment in experiments:
            experimentsListreply.experiment.extend([experiment])
        context.set_code(grpc.StatusCode.OK)
        return experimentsListreply

    def GetExperimentDetails(self, request, context):
        try:
            experiment: HpoExperiment = hpo_service.instance.getExperiment(request.experiment_name)
            experimentDetailsReply = hpo_pb2.ExperimentDetails()
            experimentDetailsReply.experiment_name = experiment.experiment_name
            experimentDetailsReply.direction = experiment.direction
            experimentDetailsReply.hpo_algo_impl = experiment.hpo_algo_impl
            # reply.id_ = experiment.id_
            experimentDetailsReply.objective_function = experiment.objective_function
            # TODO:: expand tunables message
            # reply.tunables = experiment.tunables
            experimentDetailsReply.started = experiment.started
            context.set_code(grpc.StatusCode.OK)
            return experimentDetailsReply
        except ExperimentNotFoundError:
            context.set_code(grpc.StatusCode.NOT_FOUND)
            context.set_details('Could not find experiment: %s' % request.experiment_name)
            return


    def NewExperiment(self, request, context):
        if request.hpo_algo_impl in ("optuna_tpe", "optuna_tpe_multivariate", "optuna_skopt"):
            tuneables = []
            for tuneable in request.tuneables:
                tuneables.append(json.loads(MessageToJson(tuneable, preserving_proto_field_name=True)))
            hpo_service.instance.newExperiment(None, request.experiment_name,
                                                                           request.total_trials, request.parallel_trials,
                                                                           request.direction, request.hpo_algo_impl,
                                                                           request.objective_function,
                                                                           tuneables, request.value_type)
            hpo_service.instance.startExperiment(request.experiment_name)
            experiment: HpoExperiment = hpo_service.instance.getExperiment(request.experiment_name)
            newExperimentReply: NewExperimentsReply = NewExperimentsReply()
            newExperimentReply.trial_number = experiment.trialDetails.trial_number
            context.set_code(grpc.StatusCode.OK)
            return newExperimentReply
        else:
            context.set_code(grpc.StatusCode.INVALID_ARGUMENT)
            context.set_details('Invalid algorithm: %s' % request.hpo_algo_impl)
            return

    def GetTrialConfig(self, request, context):
        if hpo_service.instance.containsExperiment(request.experiment_name):
            if(hpo_service.instance.get_trial_number(request.experiment_name) == request.trial):
                data = json.loads(hpo_service.instance.get_trial_json_object(request.experiment_name))
                trialConfig : hpo_pb2.TrialConfig = hpo_pb2.TrialConfig()
                logger.debug("New config for experiment {}, trial {}".format(request.experiment_name, request.trial))
                for config in data:
                    tunable: hpo_pb2.TunableConfig = hpo_pb2.TunableConfig()
                    tunable.name = config['tunable_name']
                    tunable.value = config['tunable_value']
                    trialConfig.config.extend([tunable])
                    logger.debug("{}: {}".format(tunable.name, tunable.value))

                context.set_code(grpc.StatusCode.OK)
                return trialConfig
            else:
                context.set_code(grpc.StatusCode.INVALID_ARGUMENT)
                context.set_details('Invalid trial number {} for experiment: {}'.format(str(request.trial), request.experiment_name) )
        else:
            context.set_code(grpc.StatusCode.NOT_FOUND)
            context.set_details('Could not find experiment: %s' % request.experiment_name)
        return hpo_pb2.TunableConfig()

    def UpdateTrialResult(self, request, context):
        if (hpo_service.instance.doesNotContainExperiment(request.experiment_name) ):
            context.set_code(grpc.StatusCode.NOT_FOUND)
            context.set_details('Experiment not found!')
            return hpo_pb2.ExperimentTrialReply()
        if ( request.trial != hpo_service.instance.get_trial_number(request.experiment_name)):
            context.set_code(grpc.StatusCode.INVALID_ARGUMENT)
            context.set_details('Invalid trial number!')
            return hpo_pb2.ExperimentTrialReply()

        hpo_service.instance.set_result(request.experiment_name,
                                        request.result,
                                        request.value_type,
                                        request.value)
        context.set_code(grpc.StatusCode.OK)
        return hpo_pb2.ExperimentTrialReply()

    def GenerateNextConfig(self, request, context):
        trial_number = hpo_service.instance.get_trial_number(request.experiment_name)
        nextConfigReply : NewExperimentsReply = NewExperimentsReply()
        nextConfigReply.trial_number = trial_number
        context.set_code(grpc.StatusCode.OK)
        return nextConfigReply

    def GetRecommendedConfig(self, request, context):
        if( hpo_service.instance.doesNotContainExperiment(request.experiment_name) ):
            context.set_code(grpc.StatusCode.NOT_FOUND)
            context.set_details('Experiment not found!')
            return RecommendedConfigReply()

        if (-1 != hpo_service.instance.get_trial_number(request.experiment_name)):
            context.set_code(grpc.StatusCode.FAILED_PRECONDITION)
            context.set_details('Experiment has not yet finished running!')
            return RecommendedConfigReply()

        recommendedConfig = hpo_service.instance.get_recommended_config(request.experiment_name)
        recommendedConfigReply : RecommendedConfigReply = RecommendedConfigReply()
        recommendedConfigReply.experiment_name = recommendedConfig["experiment_name"]
        recommendedConfigReply.direction = recommendedConfig["direction"]

        recommendedConfigReply.optimal_value.objective_function = recommendedConfig["optimal_value"]["objective_function"]["name"]
        recommendedConfigReply.optimal_value.value = recommendedConfig["optimal_value"]["objective_function"]["value"]
        recommendedConfigReply.optimal_value.value_type = recommendedConfig["optimal_value"]["objective_function"]["value_type"]

        for tunable in recommendedConfig["optimal_value"]["tunables"]:
            tunableConfig : TunableConfig = TunableConfig()
            tunableConfig.name = tunable["name"]
            tunableConfig.value = tunable["value"]
            tunableConfig.value_type = tunable["value_type"]
            recommendedConfigReply.tunables.append(tunableConfig)

        context.set_code(grpc.StatusCode.OK)
        return recommendedConfigReply

def serve():
    server = grpc.server(futures.ThreadPoolExecutor(max_workers=10))
    hpo_pb2_grpc.add_HpoServiceServicer_to_server(HpoService(), server)
    server.add_insecure_port(host_name + ':' + str(server_port))
    print("Starting gRPC server at http://%s:%s" % (host_name, server_port))

    server.start()
    server.wait_for_termination()


if __name__ == '__main__':
    logging.basicConfig()
    serve()
