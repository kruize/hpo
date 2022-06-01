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
import psycopg2

from datetime import datetime
from logger import get_logger

import pg_connection

rank = 1

logger = get_logger(__name__)


def insert_experiment_data(experiment_name, search_space_json, obj_function):
    """ insert a new experiment, search_space_json and objective_function into the experiment table """
    sql = """INSERT INTO experiment(experiment_name,search_space,objective_function,created_at)
             VALUES(%s, %s, %s, %s);"""
    conn = None
    try:
        experiment_name = experiment_name.replace("-", "_")
        conn = pg_connection.connect_to_pg()
        # create a new cursor
        cur = conn.cursor()
        # execute the INSERT statement
        cur.execute(sql, (experiment_name, str(search_space_json), obj_function, datetime.now()))

        # commit the changes to the database
        conn.commit()
        # close communication with the database
        cur.close()
    except (Exception, psycopg2.DatabaseError) as error:
        logger.error(error)
        return error
    finally:
        if conn is not None:
            conn.close()


def insert_trial_details(json_object, trial_json):
    """ insert experiment's trial details """
    sql = """INSERT INTO experiment_trial_details (trial_number, rank, experiment_name, trial_config, results_value,
             trial_result_status, created_at) VALUES(%s, %s, %s, %s, %s, %s, %s);"""
    conn = None
    global rank
    try:
        experiment_name = str(json_object["experiment_name"]).replace("-", "_")
        conn = pg_connection.connect_to_pg()
        # create a new cursor
        cur = conn.cursor()
        # execute the INSERT statement
        cur.execute(sql, (json_object["trial_number"], rank, experiment_name, trial_json,
                          json_object["result_value"], json_object["trial_result"], datetime.now()))

        # commit the changes to the database
        conn.commit()
        rank += 1
        # close communication with the database
        cur.close()
        # call the function to sort the result_value and update the rank column
        response = update_rank(conn, experiment_name)
        if response:
            return response
    except (Exception, psycopg2.DatabaseError) as error:
        logger.error(error)
        return error
    finally:
        if conn is not None:
            conn.close()


def update_rank(conn, experiment_name):
    cur = conn.cursor()
    sql = "select results_value from experiment_trial_details where experiment_name = '{}' order by results_value"\
        .format(experiment_name)
    cur.execute(sql)
    new_rank = 1
    try:
        for row in cur.fetchall():
            sql = "UPDATE experiment_trial_details SET rank = {} where results_value = {} and experiment_name = '{}'"\
                .format(new_rank, row[0], experiment_name)
            cur.execute(sql)
            new_rank += 1
        conn.commit()
    except (Exception, psycopg2.DatabaseError) as error:
        logger.error(error)
        return error


def get_recommended_configs(trial_number, experiment_name):
    conn = None
    json_list = []
    try:
        conn = pg_connection.connect_to_pg()
        cur = conn.cursor()

        # check if the requested experiment is present in DB
        sql = "SELECT EXISTS(SELECT 1 from experiment_trial_details where experiment_name = '{}')"\
            .format(experiment_name)
        cur.execute(sql)
        query_result = cur.fetchall()[0][0]
        if query_result == 0:
            return "Experiment not found"

        # check if the requested trials has been completed or not
        sql = "SELECT count(trial_number) from experiment_trial_details where experiment_name = '{}'"\
            .format(experiment_name)
        cur.execute(sql)
        query_result = cur.fetchall()[0][0]
        if query_result < trial_number:
            return "Trials not completed yet or exceeds the provided trial limit"

        print("Fetching best configs from top {} trials...\n".format(trial_number))
        sql = "SELECT trial_number,rank,experiment_name,trial_config, results_value,trial_result_status from " \
              "experiment_trial_details where experiment_name = '{}' and trial_number between 0 and {} order by rank"\
            .format(experiment_name, trial_number - 1)

        cur.execute(sql)
        for row in cur.fetchall():
            json_dict = {'Trial_Number': row[0], 'Rank': row[1], 'Experiment_Name': row[2], 'Trial_Config': row[3],
                         'Results_Value': row[4], 'Trial_Result_Status': row[5]}
            json_list.append(json_dict)

        cur.close()

    except (Exception, psycopg2.DatabaseError) as error:
        logger.error(error)
        return error
    finally:
        if conn is not None:
            conn.close()
        return json.dumps(json_list)
