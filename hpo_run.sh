
## Step1 : Start HPOaaS. The service is available at "http://localhost:8085/"
./start_hpo_servers.sh

## Step 2 : Start a new experiment with provided search space.
curl  -v -s -H 'Content-Type: application/json' http://localhost:8085/experiment_trials -d '{"experiment_id" : "a123", "url" : "http://localhost:8080/searchSpace", "operation" : "EXP_TRIAL_GENERATE_NEW"}'

## Loop through 100 trials to run the experiment
for i in {1..100}
do

## Step 3: Get the HPO config from HPOaaS
curl -H 'Accept: application/json' "http://localhost:8085/experiment_trials?experiment_id=a123&trial_number=${i}"

## Step 4: Run the benchmark with HPO config.
./runbenchmark.sh --config="${HPO_CONFIG}"

## Step 5: Send the results of benchmark to HPOaaS
curl  -v -s -H 'Content-Type: application/json' http://localhost:8085/experiment_trials -d '{"experiment_id" : "a123", "trial_number": 0, "trial_result": "success", "result_value_type": "double", "result_value": 98.78, "operation" : "EXP_TRIAL_RESULT"}'


## Step 6 : Generate a subsequent trial
curl  -v -s -H 'Content-Type: application/json' http://localhost:8085/experiment_trials -d '{"experiment_id" : "a123", "url" : "http://localhost:8080/searchSpace", "operation" : "EXP_TRIAL_GENERATE_SUBSEQUENT"}'

done

