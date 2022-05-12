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
import sqlite3

from datetime import date


def conn_create():
    conn = sqlite3.connect('./db/hpo.db')

    print("Opened database successfully")

    try:
        conn.execute('''CREATE TABLE EXPERIMENT
                 (name VARCHAR(512) PRIMARY KEY  NOT NULL,
                 search_space   VARCHAR(512)    NOT NULL,
                 objective_function  VARCHAR(512)  NOT NULL,
                 created_at   TIMESTAMP);''')
    except:
        sqlite3.OperationalError

    print("EXPERIMENT Table created successfully")
    try:
        conn.execute('''CREATE TABLE EXPERIMENT_DETAILS
             (id INT PRIMARY KEY     NOT NULL,
             experiment_name VARCHAR(512) NOT NULL,
             tunable_id     INT        NOT NULL,    
             results        FLOAT     NOT NULL,
             created_at     DATETIME);''')
    except:
        sqlite3.OperationalError

    print("EXPERIMENT_DETAILS Table created successfully")

    try:
        conn.execute('''CREATE TABLE TUNABLES
                 (id INT PRIMARY KEY     NOT NULL,
                 tunable_name   VARCHAR(512)    NOT NULL,
                 tunable_value  FLOAT   NOT NULL);''')
    except:
        sqlite3.OperationalError

    print("TUNABLES Table created successfully")


class DBConnectionHandler:

    def insert_data(self, exp_name, search_space, obj_function):

        self.execute("INSERT INTO EXPERIMENT (NAME,SEARCH_SPACE,OBJECTIVE_FUNCTION,CREATED_AT) "
                     "VALUES (?, ?, ?)", (exp_name, search_space, obj_function, date.today()))
        self.commit()

        print("Records created successfully")

    def get_data(self):
        cursor = self.execute("SELECT name, search_space, objective_function from EXPERIMENT")
        for row in cursor:
            print("NAME = ", row[0])
            print("SEARCH_SPACE = ", row[1])
            print("OBJECTIVE_FUNCTION = ", row[2], "\n")

        print("Operation done successfully")
