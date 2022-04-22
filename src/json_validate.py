import jsonschema
from jsonschema import validate, draft7_format_checker

subs_trial_generate_schema = {
    "type": "object",
    "properties": {
        "experiment_id": {"type": "string"},        
        "operation": {
            "enum": [
                "EXP_TRIAL_GENERATE_SUBSEQUENT"
            ]
        }
    },
    "required": ["experiment_id", "operation"],
    "additionalProperties": False
}

trial_generate_schema = {
    "type": "object",
    "properties": {
       "operation": {
            "enum": [
                "EXP_TRIAL_GENERATE_NEW"
            ]
        },
        "search_space":{
            "type":"object",
            "properties": {
                "experiment_name": {"type": "string"},
                "total_trials": {"type": "integer"},
                "parallel_trials": {"type": "integer"},
                "experiment_id": {"type": "string"},        
                "value_type": {"type": "string"},        
                "hpo_algo_impl": {"type": "string"},        
                "objective_function": {"type": "string"},        
                "tunables":{
                    "type":"array",
                    "value_type": {"type": "string"},        
                    "name": {"type": "string"},        
                    "lower_bound": {"type": "number"},        
                    "upper_bound": {"type": "number"},        
                    "step": {"type": "number"},
                    "choices":{"type":"array"}
                },        
                "direction": {"type": "string"},                 
            },
            "required": ["experiment_name", "total_trials", "objective_function", "tunables", "direction"]        
        }
    },
    "required": ["search_space", "operation"],
    "additionalProperties": False
}


def validate_trial_generate_json(trial_generate_json):
    try:
        if trial_generate_json["operation"] == "EXP_TRIAL_GENERATE_NEW":
            validate(instance=trial_generate_json, schema=trial_generate_schema, format_checker=draft7_format_checker)
        else:
            validate(instance=trial_generate_json, schema=subs_trial_generate_schema, format_checker=draft7_format_checker)
    except jsonschema.exceptions.ValidationError as err:
        print(err)
        return False
    return True
