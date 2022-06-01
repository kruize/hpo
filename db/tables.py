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
import sys
import psycopg2
from logger import get_logger

file_dir = os.path.dirname(__file__)
sys.path.append(file_dir)
import pg_connection

logger = get_logger(__name__)


def create_tables():
    """ create tables in the PostgreSQL database"""
    commands = (
        """
        CREATE TABLE experiment (
            experiment_name VARCHAR(512) PRIMARY KEY  NOT NULL,
            search_space TEXT  NOT NULL,
            objective_function  VARCHAR(512)  NOT NULL,
            created_at   TIMESTAMP
        )
        """,
        """
        CREATE TABLE experiment_trial_details (
            id SERIAL PRIMARY KEY,
            trial_number INTEGER,
            rank INTEGER,
            experiment_name VARCHAR NOT NULL,
            trial_config VARCHAR,
            results_value FLOAT,
            trial_result_status  VARCHAR,
            created_at  TIMESTAMP,
            FOREIGN KEY (experiment_name) 
            REFERENCES experiment (experiment_name)
            ON UPDATE CASCADE ON DELETE CASCADE                
        )
        """)
    conn = None
    try:
        conn = pg_connection.connect_to_pg()
        cur = conn.cursor()
        # create table one by one
        for command in commands:
            cur.execute(command)
        logger.info("Tables created")
        # close communication with the PostgreSQL database server
        cur.close()
        # commit the changes
        conn.commit()
    except (Exception, psycopg2.DatabaseError) as error:
        logger.error(error)
    finally:
        if conn is not None:
            conn.close()
