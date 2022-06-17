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
import psycopg2

from logger import get_logger

from src.db.config import config

logger = get_logger(__name__)


def connect_to_pg():
    """ Connect to the PostgreSQL database server """
    conn = None
    try:
        # read connection parameters
        params = config()

        # connect to the PostgreSQL server
        logger.info('Connecting to the PostgreSQL database...')
        conn = psycopg2.connect(**params)
        logger.info('Successfully Connected!')

        return conn
    except (Exception, psycopg2.DatabaseError) as error:
        logger.error("Failed to start DB")
        if conn is not None:
            conn.close()
            logger.info('Database connection closed.')
        return conn
