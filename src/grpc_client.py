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

from __future__ import print_function

import logging
import os

import click
import json

import grpc
from gRPC import hpo_pb2_grpc, hpo_pb2
from google.protobuf.json_format import MessageToJson, ParseError
from google.protobuf.json_format import Parse, ParseDict
import json_validate
from logger import get_logger

logger = get_logger(__name__)

default_host_name="localhost"
default_server_port = 50051
@click.group()
def main():
    """A HPO command line tool to allow interaction with HPO service"""
    logging.basicConfig()
    pass

@main.command()
def count():
    """Return a count of experiments currently running"""
    empty = hpo_pb2.NumberExperimentsReply()
    fun = lambda stub: stub.NumberExperiments(empty)
    response = run(fun)
    click.echo(" Number of running experiments: {}".format(response.count))

@main.command()
def list():
    """List names of all experiments currently running"""
    empty = hpo_pb2.NumberExperimentsReply()
    fun = lambda stub: stub.ExperimentsList(empty)
    experiments: hpo_pb2.ExperimentsListReply = run(fun)
    if experiments != None:
        click.echo("Running Experiments:")
        for experiment in experiments.experiment:
            click.echo(" %s" % experiment)
    else:
        raise click.ClickException(" No running experiments found")


@main.command()
@click.option("--name", prompt=" Experiment name", type=str)
def show(name):
    """Show details of running experiment"""
    expr: hpo_pb2.ExperimentNameParams = hpo_pb2.ExperimentNameParams()
    expr.experiment_name = name
    fun = lambda stub: stub.GetExperimentDetails(expr)
    experiment: hpo_pb2.ExperimentDetails = run(fun)
    json_obj = MessageToJson(experiment)
    click.echo(json_obj)

@main.command()
@click.option("--file", prompt=" Experiment configuration file path", type=str)
def new(file):
    """Create a new experiment"""
    # TODO: validate file path
    with open(file, 'r') as json_file:
        data = json.load(json_file)
        try:
            message: hpo_pb2.ExperimentDetails = ParseDict(data, hpo_pb2.ExperimentDetails())
            # further validate the JSON structure and proceed accordingly
            isInvalid = json_validate.validate_search_space(data)
            if isInvalid:
                logger.error(isInvalid)
                return
        except ParseError as pErr :
            raise click.ClickException("Unable to parse: " + file)
    click.echo(" Adding new experiment: {}".format(message.experiment_name))
    fun = lambda stub: stub.NewExperiment(message)
    response: hpo_pb2.NewExperimentsReply = run(fun)
    click.echo("Trial Number: {}".format(response.trial_number))


@main.command()
@click.option("--name", prompt=" Experiment name", type=str)
def delete(name):
    """Delete an experiment"""
    expr: hpo_pb2.ExperimentNameParams = hpo_pb2.ExperimentNameParams()
    expr.experiment_name = name
    fun = lambda stub: stub.DeleteExperiment(expr)
    run(fun)
    click.echo("Deleted: {}".format(name))


@main.command()
@click.option("--name", prompt=" Experiment name", type=str)
@click.option("--trial", prompt=" Trial number", type=int)
def config(name, trial):
    """Obtain a configuration set for a particular experiment trail"""
    expr: hpo_pb2.ExperimentTrial = hpo_pb2.ExperimentTrial()
    expr.experiment_name = name
    expr.trial = trial
    fun = lambda stub: stub.GetTrialConfig(expr)
    trial_config: hpo_pb2.TrialConfig = run(fun)
    json_obj = MessageToJson(trial_config)
    click.echo(json_obj)

@main.command()
@click.option("--name", prompt=" Enter name", type=str)
@click.option("--trial", prompt=" Enter trial number", type=int)
@click.option("--result", prompt=" Enter trial result", type=str)
@click.option("--value_type", prompt=" Enter result type", type=str)
@click.option("--value", prompt=" Enter result value", type=float)
def result(name, trial, result, value_type, value):
    """Update results for a particular experiment trail"""
    trialResult: hpo_pb2.ExperimentTrialResult = hpo_pb2.ExperimentTrialResult()
    trialResult.experiment_name = name
    trialResult.trial = trial
    trialResult.result = hpo_pb2._EXPERIMENTTRIALRESULT_RESULT.values_by_name[result].number
    trialResult.value_type = value_type
    trialResult.value = value
    fun = lambda stub: stub.UpdateTrialResult(trialResult)
    hpo_pb2.TrialConfig = run(fun)
    click.echo("Success: Updated Trial Result")

@main.command()
@click.option("--name", prompt=" Enter name", type=str)
def next(name):
    """Generate next configuration set for running experiment"""
    experiment: hpo_pb2.ExperimentNameParams = hpo_pb2.ExperimentNameParams()
    experiment.experiment_name = name
    fun = lambda stub : stub.GenerateNextConfig(experiment)
    reply: hpo_pb2.NewExperimentsReply = run(fun)
    click.echo("Next Trial: {}".format(reply.trial_number))

@main.command()
@click.option("--name", prompt=" Enter name", type=str)
def recommended(name):
    """Generate recommended configuration set for experiment"""
    experiment: hpo_pb2.ExperimentNameParams = hpo_pb2.ExperimentNameParams()
    experiment.experiment_name = name
    fun = lambda stub : stub.GetRecommendedConfig(experiment)
    recommendedConfig: hpo_pb2.RecommendedConfigReply = run(fun)
    click.echo("Recommended configuration for experiment: {}".format(recommendedConfig.experiment_name))
    click.echo("\t Direction: {}".format(recommendedConfig.direction))
    click.echo("\t Objective Function: {}".format(recommendedConfig.optimal_value.objective_function))
    click.echo("\t Optimal Value: {}".format(recommendedConfig.optimal_value.value))
    click.echo("\t Tunables: ")
    for tunable in recommendedConfig.tunables:
        click.echo("\t\t {}: {}".format(tunable.name, tunable.value))

def run(func):
    # NOTE(gRPC Python Team): .close() is possible on a channel and should be
    # used in circumstances in which the with statement does not fit the needs
    # of the code.

    if "HPO_HOST" in os.environ:
        host_name = os.environ.get('HPO_HOST')
    else :
        host_name = default_host_name

    if "HPO_PORT" in os.environ:
        server_port = os.environ.get('HPO_PORT')
    else :
        server_port = default_server_port



    with grpc.insecure_channel(host_name + ':' + str(server_port)) as channel:
        stub = hpo_pb2_grpc.HpoServiceStub(channel)
        try:
            response = func(stub)
            return response
        except grpc.RpcError as rpc_error:
            if rpc_error.code() == grpc.StatusCode.CANCELLED:
                pass
            elif rpc_error.code() == grpc.StatusCode.UNAVAILABLE:
                raise click.ClickException("An error occurred executing command: {}".format(rpc_error.details()))
            elif rpc_error.code() == grpc.StatusCode.NOT_FOUND:
                raise click.ClickException(rpc_error.details())
            elif rpc_error.code() == grpc.StatusCode.INVALID_ARGUMENT:
                raise click.ClickException(rpc_error.details())
            elif rpc_error.code() == grpc.StatusCode.ALREADY_EXISTS:
                raise click.ClickException(rpc_error.details())
            else:
                raise click.ClickException("Received unknown RPC error: code={" + str(rpc_error.code()) + "} message={" + rpc_error.details() + "}")
        return

def NewExperiment(stub, **args):
    empty = hpo_pb2.NumberExperimentsReply()
    response = stub.NumberExperiments(empty)
    click.echo("HpoService client received: %s" % response.count)


if __name__ == "__main__":
    main()
