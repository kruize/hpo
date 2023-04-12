# Kruize HPO

## Goal

Provide Kruize Hyper Parameter Optimization (HPO) to choose the optimal values for hyperparameters provided by the user for any model.

## Background

While talking to Kruize Autotune users, we came across a number of scenarios where Hyper Parameter Optimization would be useful outside of the Autotune context (Kubernetes), including on bare metal and even on containerized but non-Kubernetes scenarios. This is when it was felt that it would be nice to separate the HPO part of Autotune as an independent service with a well defined API that will allow this feature to be used much more broadly.

## Motivation

Machine learning is a process of teaching a system to make accurate predictions based on the data fed. Hyperparamter optimization (/ tuning) helps to choose the right set of parameters for a learning algorithm. HPO uses different methods like Manual, Random search, Grid search, Bayesian optimization. Kruize HPO currently uses Bayesian optimization because of the multiple advantages that it provides.

There are a number of Open Source modules / projects that provide hyperparameter optimization functions (Eg Optuna, hyperopt etc). Some modules are better suited for solving particular problems than others. However every module has a different API and supports varied workflows. This repo provides a thin API layer (REST, gRPC) that simplifies choosing both the modules / projects as well as the specific algorithm. This helps to hide all of the complexity of understanding individual HPO modules and their intricacies while at the same time providing an easy to use interface that requires the search space data to be provided in JSON format.

## HPO Basics
### What is HPO?
Hyperparameter optimization(HPO) is choosing a set of optimal hyperparameters that yields an optimal performance based on the predefined objective function. 

### Definitions
- **_Search space:_** List of tunables with the ranges to optimize.
- **_Experiment:_** A set of trials to find the optimal set of tunable values for a given objective function.
- **_Trials:_** Each trial is an execution of an objective function by running a benchmark / application with the configuration generated by Kruize HPO.
- **_Objective function:_** Typically an algebraic expression that either needs to be maximized or minimized. Eg, maximize throughput, minimize cost etc

## Kruize HPO Architecture
![Kruize HPO Architecture](/design/kruize_hpo.png)
The current architecture of Kruize HPO consists of a thin abstraction layer that provides a common REST API and gRPC interface. It provides an interface for integrating with Open Source projects / modules that provide HPO functionality. Currently it only supports the Optuna OSS Project. It provides a simple HTTP server through which the REST APIs can be accessed.

Kruize HPO supports the following ways of deployment:
- Bare Metal
- Container
- Kubernetes (Minikube / Openshift)

## REST API

See the [API README](/design/API.md) for more details on the Autotune REST API.

## Workflow of Kruize HPO
- Step 1: Arrive at an objective function for your specific performance goal and capture it as a single algebraic expression.
- Step 2: Capture the relevant tunables and ranges within which they operate. Create a search space JSON with the tunable details.
- Step 3: Start an experiment by doing a POST of the search space to the URL as mentioned in the REST API above. On success, this should return a “trial\_number”.
- Step 4: Query Kruize HPO for the “trial config” associated with the “trial\_number”.
- Step 5: Start a benchmark run with the “trial config”.
- Step 6: POST the results of the trial back to Kruize HPO.
- Step 7: Generate a subsequent trial.
- Step 8: Loop through Step 4 to 7 for the remaining trials of an experiment.
- Step 9: Examine the results log to determine the best result for your experiment.

## Supported Modules & Algorithms
Currently Kruize HPO supports only Optuna which is a Open Source Framework for many HPO algorithms. Here are a few of the algorithms supported by Optuna
- Optuna
  * TPE:  Tree-structured Parzen Estimator sampler. (Default)
  * TPE with multivariate
  * optuna-scikit

The above tools mentioned supports Bayesian optimization which is part of a class of sequential model-based optimization(SMBO) algorithms for using results from a previous trial to improve the next.

## Installation

You can access the Kruize HPO Operate-first instance to make use of it without installing by running the following command:

`$ ./deploy_hpo.sh -c operate-first`

Also, Kruize HPO can be installed natively on Linux, as a container or in minikube / openshift
1. Native
    `$ ./deploy_hpo.sh -c native`
2. Container
    `$ ./deploy_hpo.sh -c docker`
3. Minikube
    `$ ./deploy_hpo.sh -c minikube`
4. Openshift
    `$ ./deploy_hpo.sh -c openshift`
    
To test in Operate first, please use
 `$ ./deploy_hpo.sh -c operate-first`

You can run a specific version of the Kruize HPO container
    `$ ./deploy_hpo.sh -c minikube -o image:tag`

## Operate First
We have deployed Kruize HPO on [Operate First](https://www.operate-first.cloud/about) community cloud using namespace 'openshift-tuning', to promote open operations. Operate First is a community of open source contributors including developers, data scientists and SREs, where developers and operators collaborate on production community cloud for operational considerations for their code and other artifacts. For more information on operate-first, please visit https://www.operate-first.cloud/

 You can access HPO on operate first by running the following command:
`$ ./deploy_hpo.sh -c operate-first`

## How to make use of Kruize HPO for my use case?

We would recommend that you start with the [hpo\_demo\_setup.sh](https://github.com/kruize/kruize-demos/blob/main/hpo_demo_setup.sh) script and customize it for your use case.

## Contributing

We welcome your contributions! See [CONTRIBUTING.md](/CONTRIBUTING.md) for more details.

## License

Apache License 2.0, see [LICENSE](/LICENSE).
