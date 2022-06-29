import jsonschema
from jsonschema import validate, draft7_format_checker
from utils import HPOSupportedTypes, HPOErrorConstants
from logger import get_logger

logger = get_logger(__name__)

subs_trial_generate_schema = {
    "type": "object",
    "properties": {
        "experiment_name": {"type": "string"},
        "operation": {
            "enum": [
                "EXP_TRIAL_GENERATE_SUBSEQUENT"
            ]
        }
    },
    "required": ["experiment_name", "operation"],
    "additionalProperties": False
}

result_trial_schema = {
    "type": "object",
    "properties": {
        "experiment_name": {"type": "string"},
        "trial_number": {"type": "integer"},
        "trial_result": {"type": "string"},
        "result_value_type": {"type": "string"},
        "result_value": {"type": "number"},
        "operation": {
            "enum": [
                "EXP_TRIAL_RESULT"
            ]
        }
    },
    "required": ["experiment_name", "trial_number", "trial_result", "result_value_type", "result_value", "operation"],
    "additionalProperties": False
}

stop_experiment_schema = {
    "type": "object",
    "properties": {
        "experiment_name": {"type": "string"},
        "operation": {
            "enum": [
                "EXP_STOP"
            ]
        }
    },
    "required": ["experiment_name", "operation"],
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
        "search_space": {
            "type": "object",
            "properties": {
                "experiment_name": {"type": "string"},
                "total_trials": {"type": "integer"},
                "parallel_trials": {"type": "integer"},
                "experiment_id": {"type": "string"},
                "value_type": {"type": "string"},
                "hpo_algo_impl": {"type": "string"},
                "objective_function": {"type": "string"},
                "tunables": {
                    "type": "array",
                    "value_type": {"type": "string"},
                    "name": {"type": "string"},
                    "lower_bound": {"type": "number"},
                    "upper_bound": {"type": "number"},
                    "step": {"type": "number"},
                    "choices": {"type": "array"}
                },
                "direction": {"type": "string"}
            },
            "required": ["experiment_name", "experiment_id", "total_trials", "objective_function", "tunables",
                         "direction"],
            "additionalProperties": False
        }
    },
    "required": ["search_space", "operation"],
    "additionalProperties": False
}


def validate_trial_generate_json(trial_generate_json):
    errorMsg = ""
    try:
        if trial_generate_json["operation"] == "EXP_TRIAL_GENERATE_NEW":
            validate(instance=trial_generate_json, schema=trial_generate_schema, format_checker=draft7_format_checker)
            # perform search_space validation
            search_space = trial_generate_json["search_space"]
            errorMsg = validate_search_space(search_space)
        elif trial_generate_json["operation"] == "EXP_TRIAL_GENERATE_SUBSEQUENT":
            validate(instance=trial_generate_json, schema=subs_trial_generate_schema,
                     format_checker=draft7_format_checker)
        elif trial_generate_json["operation"] == "EXP_TRIAL_RESULT":
            validate(instance=trial_generate_json, schema=result_trial_schema, format_checker=draft7_format_checker)
        elif trial_generate_json["operation"] == "EXP_STOP":
            validate(instance=trial_generate_json, schema=stop_experiment_schema, format_checker=draft7_format_checker)
        elif not str(trial_generate_json["operation"]) or not str(trial_generate_json["operation"]).strip() or \
                trial_generate_json["operation"] is None:
            errorMsg = "Parameters" + HPOErrorConstants.VALUE_MISSING
        else:
            errorMsg = HPOErrorConstants.INVALID_OPERATION

        return errorMsg
    except jsonschema.exceptions.ValidationError as err:
        # Check if the exception is due to empty or null required parameters and prepare the response accordingly
        if any(word in err.message for word in HPOErrorConstants.JSON_NULL_VALUES):
            errorMsg = "Parameters" + HPOErrorConstants.VALUE_MISSING
            return errorMsg
        # Modify the error response in case of additional properties error
        elif str(err.message).__contains__('('):
            errorMsg = str(err.message).split('(')
            return errorMsg[0]
        else:
            return err.message


def validate_search_space(search_space):
    validationErrorMsg = ""

    # loop through the json to check for empty or null values
    for key in search_space:

        # Check if any of the key is empty or null
        if not (str(search_space[key]) and str(search_space[key]).strip()):
            validationErrorMsg = ",".join([validationErrorMsg, "Parameters" + HPOErrorConstants.VALUE_MISSING])

        # Check if total trials is less than one
        elif str(key) == "total_trials" and search_space[key] < 1:
            validationErrorMsg = ",".join([validationErrorMsg, HPOErrorConstants.INVALID_TOTAL_TRIALS])

        # Check if the direction is supported
        elif str(key) == "direction" and str(search_space[key]) not in HPOSupportedTypes.DIRECTIONS_SUPPORTED:
            validationErrorMsg = ",".join([validationErrorMsg, HPOErrorConstants.DIRECTION_NOT_SUPPORTED])

        # Check if hpo_algo_impl is supported
        elif str(key) == "hpo_algo_impl" and str(search_space[key]) not in HPOSupportedTypes.ALGOS_SUPPORTED:
            print("validationErrorMsg: ", validationErrorMsg)
            validationErrorMsg = ",".join([validationErrorMsg, HPOErrorConstants.HPO_ALGO_NOT_SUPPORTED])

        # Check if value_type is supported
        elif str(key) == "value_type" and str(search_space[key]) not in HPOSupportedTypes.VALUE_TYPES_SUPPORTED:
            validationErrorMsg = ",".join([validationErrorMsg, HPOErrorConstants.VALUE_TYPE_NOT_SUPPORTED])

    return validationErrorMsg.lstrip(',')
