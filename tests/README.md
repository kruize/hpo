# **HPO tests**


HPO functional tests to validate the functionality of Hyper parameter optimization & the HPO REST APIs

## High level Test Scenarios

- Post experiments with both valid & invalid values in the experiment json
- Get the HPO generated config using both valid & invalid values for the experiment id & trial number
- Post experiment results with both valid & invalid values in the experiment results json

## Functional tests description

### Hyperparameter Optimization module tests

- ** Hyper Parameter Optimization (HPO) API tests**

  Here we validate the HPO API - /experiment_trials
  
  The test does the following:

  - Starts the HPO service using the deploy_hpo.sh script
  - Validates HPO result for following scenarios:
  	1. Post invalid and valid experiments to HPO /experiment_trials API and validate the results
  	2. Post the same experiment again to HPO /experiment_trials API with operation set to "EXP_TRIAL_GENERATE_NEW" and validate the result
  	3. Post the same experiment again to HPO /experiment_trials API with the operation set to "EXP_TRIAL_GENERATE_SUBSEQUENT" after we post the result for the previous trial, and check if subsequent trial number is generated
  	4. Query the HPO /experiment_trials API with different invalid combination of experiment id and trial number
  	5. Query the HPO /experiment_trials API for valid experiment id and trial number and validate the result
  	6. Post the same experiment again to HPO /experiment_trials API with the operation set to "EXP_TRIAL_GENERATE_SUBSEQUENT" after we post the result for the previous trial. Now query the API using that trial number and validate the result
  	7. Post invalid and valid experiment results to HPO /experiment_trials API and validate the result
  	8. Post duplicate experiment results to HPO /experiment_trials API and validate the result
  	9. Post different experiment results to HPO /experiment_trials API for the same experiment id and validate the result

## Supported Clusters
- Native

## Prerequisites for running the tests:

- None 

Clone the kruize/hpo repo using the below command:

```
git clone https://github.com/kruize/hpo.git

```

## How to run the tests?

Use the below command to test:

```
<AUTOTUNE_REPO>/tests/test_hpo.sh -c native [--tctype=functional] [--testsuite=Group of tests that you want to perform] [--testcase=Particular test case that you want to test] [--resultsdir=results directory]
```

Where values for test_hpo.sh are:

```
usage: test_hpo.sh [ -c ] : cluster type. Supported type - native
			[ -r ] : Location of benchmarks
			[ --tctype ] : optional. Testcases type to run, default is functional (runs all functional tests)
			[ --testsuite ] : Testsuite to run. Use testsuite=help, to list the supported testsuites
			[ --testcase ] : Testcase to run. Use testcase=help along with the testsuite name to list the supported testcases in that testsuite
			[ --resultsdir ] : optional. Results directory location, by default it creates the results directory in current working directory

Note: If you want to run a particular testcase then it is mandatory to specify the testsuite

```

For example,

```
To run all tests for Hyperparameter Optimization (hpo) module execute the below command:
<AUTOTUNE_REPO>/tests/test_hpo.sh -c native --testsuite=hpo_api_tests --resultsdir=/home/results
```

## How to test a specific testcase?

To run a specific testcase execute the below command:
```
<AUTOTUNE_REPO>/tests/test_hpo.sh -c native --testsuite=hpo_api_tests --testcase=hpo_post_experiment --resultsdir=/home/results
```

To run only the basic sanity test execute the below command:
```
<AUTOTUNE_REPO>/tests/test_hpo.sh -c native --testsuite=hpo_api_tests --testcase=hpo_sanity_test --resultsdir=/home/results
```
