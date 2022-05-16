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
import os
import sqlite3

from datetime import date

db_path = os.path.abspath("hpo.db")


def conn_create():
    conn = sqlite3.connect(db_path)
    print("Opened database successfully")

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
             trial_json  VARCHAR,
             results_value  FLOAT,
             trial_result  VARCHAR,
             created_at  DATETIME,
            FOREIGN KEY (experiment_name)
            REFERENCES experiment (name));''')
        print("Experiment_Details Table created successfully")
    except:
        sqlite3.OperationalError

    try:
        cursor.execute('''CREATE TABLE configs
                 (id INTEGER PRIMARY KEY,
                 experiment_name VARCHAR,
                 best_config VARCHAR,
                 best_parameter VARCHAR,
                 best_value FLOAT,
                 recommended_config VARCHAR,
                 FOREIGN KEY (experiment_name)
                 REFERENCES experiment (name));''')
        print("Tunables Table created successfully")
    except:
        sqlite3.OperationalError


def insert_experiment_data(experiment_name, search_space_json, obj_function):
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    cursor.execute("INSERT INTO experiment (name,search_space,objective_function,created_at) "
                   "VALUES (?, ?, ?, ?)", (experiment_name, str(search_space_json), obj_function, date.today()))
    conn.commit()
    print("Record created successfully")


def insert_experiment_details(json_object, trial_json):
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    cursor.execute("INSERT INTO experiment_details (trial_number,experiment_name,trial_json,results_value,"
                   "trial_result, created_at) "
                   "VALUES (?, ?, ?, ?, ?, ?)", (json_object["trial_number"], json_object["experiment_name"],
                                                 trial_json, json_object["result_value"],
                                                 json_object["trial_result"], date.today()))
    conn.commit()
    print("Record created successfully")


def insert_config_details(experiment_name, best_config, best_parameter, best_value, recommended_config):
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    cursor.execute("INSERT INTO configs (experiment_name, best_config, best_parameter, best_value, "
                   "recommended_config, created_at) "
                   "VALUES (?, ?, ?, ?, ?, ?)", (experiment_name, best_config, best_parameter, best_value,
                                                 recommended_config, date.today()))
    conn.commit()
    print("Record created successfully")


def get_data():
    global conn
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    result = cursor.execute("SELECT name, search_space, objective_function from experiment")
    for row in result:
        print("NAME = ", row[0])
        print("SEARCH_SPACE = ", row[1])
        print("OBJECTIVE_FUNCTION = ", row[2], "\n")

    print("Operation done successfully")
