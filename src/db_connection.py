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
conn = None


def conn_create():
    global conn
    conn = sqlite3.connect(db_path)
    print("Opened database successfully")

    cursor = conn.cursor()

    try:
        cursor.execute('''CREATE TABLE experiment
                 (name VARCHAR(512) PRIMARY KEY  NOT NULL,
                 search_space   TEXT    NOT NULL,
                 objective_function  VARCHAR(512)  NOT NULL,
                 created_at   TIMESTAMP);''')
        print("EXPERIMENT Table created successfully")
    except:
        sqlite3.OperationalError

    try:
        cursor.execute('''CREATE TABLE experiment_details
             (id INT PRIMARY KEY     NOT NULL,
             experiment_name VARCHAR(512) NOT NULL,
             tunable_id     INT        NOT NULL,    
             results        FLOAT     NOT NULL,
             created_at     DATETIME);''')
        print("EXPERIMENT_DETAILS Table created successfully")
    except:
        sqlite3.OperationalError

    try:
        cursor.execute('''CREATE TABLE tunables
                 (id INT PRIMARY KEY     NOT NULL,
                 tunable_name   VARCHAR(512)    NOT NULL,
                 tunable_value  FLOAT   NOT NULL);''')
        print("Tunables Table created successfully")
    except:
        sqlite3.OperationalError


def insert_data(experiment_name, search_space_json, obj_function):
    global conn
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    cursor.execute("INSERT INTO experiment (name,search_space,objective_function,created_at) "
                   "VALUES (?, ?, ?, ?)", (experiment_name, str(search_space_json), obj_function, date.today()))
    result = cursor.execute("select id from experiment_details")
    if result.rowcount == 0:
        id = 0
    else:
        id = result.rowcount + 1
    cursor.execute("INSERT INTO experiment_details (id,experiment_name,tunable_id,results,created_at) "
                   "VALUES (?, ?, ?,?,?)", (id, experiment_name, 0, 0.0, date.today()))
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
