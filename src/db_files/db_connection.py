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
import json
import os
import sqlite3

from datetime import datetime

db_path = os.path.abspath("hpo.db")


def conn_create():
    conn = sqlite3.connect(db_path)

    cursor = conn.cursor()

    try:
        cursor.execute('''CREATE TABLE experiment
                 (name VARCHAR(512) PRIMARY KEY  NOT NULL,
                 search_space   TEXT    NOT NULL,
                 objective_function  VARCHAR(512)  NOT NULL,
                 created_at   TIMESTAMP);''')
        print("Experiment Table created successfully")
    except:
        sqlite3.OperationalError

    try:
        cursor.execute('''CREATE TABLE experiment_details
             (id INTEGER PRIMARY KEY,
             trial_number INTEGER,          
             experiment_name VARCHAR NOT NULL,
             trial_config  VARCHAR,
             results_value  FLOAT,
             trial_result_status  VARCHAR,
             created_at  TIMESTAMP,
            FOREIGN KEY (experiment_name)
            REFERENCES experiment (name));''')
        print("Experiment_Details Table created successfully")
    except:
        sqlite3.OperationalError

    try:
        cursor.execute('''CREATE TABLE configs
                 (id INTEGER PRIMARY KEY,
                 experiment_name VARCHAR,
                 best_parameter VARCHAR,
                 best_value FLOAT,
                 best_trial VARCHAR,
                 recommended_config VARCHAR,
                 created_at  TIMESTAMP,
                 FOREIGN KEY (experiment_name)
                 REFERENCES experiment (name));''')
        print("Tunables Table created successfully")
    except:
        sqlite3.OperationalError

    conn.close()


def insert_experiment_data(experiment_name, search_space_json, obj_function):
    conn = sqlite3.connect(db_path)
    try:
        conn.execute("INSERT INTO experiment (name,search_space,objective_function,created_at) "
                     "VALUES (?, ?, ?, ?)", (experiment_name, str(search_space_json), obj_function, datetime.now()))
    except:
        sqlite3.IntegrityError
        return "Experiment already exists!"

    conn.commit()
    print("Record created successfully")
    conn.close()


def insert_experiment_details(json_object, trial_json):
    conn = sqlite3.connect(db_path)
    conn.execute("INSERT INTO experiment_details (trial_number,experiment_name,trial_config,results_value,"
                 "trial_result_status, created_at) "
                 "VALUES (?, ?, ?, ?, ?, ?)", (json_object["trial_number"], json_object["experiment_name"],
                                               trial_json, json_object["result_value"],
                                               json_object["trial_result"], datetime.now()))
    conn.commit()
    print("Record created successfully")
    conn.close()


def insert_config_details(experiment_name, best_parameter, best_value, best_trial, recommended_config):
    conn = sqlite3.connect(db_path)
    conn.execute("INSERT INTO configs (experiment_name, best_parameter, best_value, best_trial, recommended_config, "
                 "created_at) VALUES (?, ?, ?, ?, ?, ?)", (experiment_name, best_parameter, best_value, best_trial,
                                                           recommended_config, datetime.now()))
    conn.commit()
    print("Final config records are inserted successfully for experiment: ", experiment_name)
    conn.close()


def get_recommended_configs(trial_number, experiment_name):
    json_list = []
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    # check if the requested experiment is present in DB
    cursor.execute("SELECT EXISTS(SELECT 1 from experiment_details where experiment_name=:experiment_name) ",
                   {"experiment_name": experiment_name})
    query_result = cursor.fetchall()[0][0]
    if query_result == 0:
        return "Experiment not found"

    # check if the requested trials has been completed or not
    cursor.execute("SELECT count(trial_number) from experiment_details where experiment_name=:experiment_name ",
                   {"experiment_name": experiment_name})
    query_result = cursor.fetchall()[0][0]
    if query_result < trial_number:
        return "Trials not completed yet or exceeds the provided trial limit"

    print("Fetching best configs from top {} trials...\n".format(trial_number))

    result = cursor.execute("SELECT experiment_name, trial_number, trial_config, results_value,trial_result_status "
                            "from experiment_details where experiment_name=:experiment_name and trial_number "
                            "between 0 and :trial_number order by results_value",
                            {"experiment_name": experiment_name, "trial_number": trial_number - 1})

    rank = 1
    for row in result.fetchall():
        json_dict = {'Rank': rank, 'Experiment_Name': row[0], 'Trial_Number': row[1], 'Trial_Config': row[2],
                     'Results_Value': row[3], 'Trial_Result_Status': row[4]}
        json_list.append(json_dict)
        rank += 1

    conn.close()
    return json.dumps(json_list)
