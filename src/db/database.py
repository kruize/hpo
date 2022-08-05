#!/usr/bin/python
import subprocess
import os

class POSTGRESQL_DB:
    POSTGRESQL_USER = "hpodbuser"
    POSTGRESQL_PASSWORD = "hpodbpwd"
    POSTGRESQL_DATABASE = "hpodb"
    POSTGRESQL_PORT = 5432
    POSTGRESQL_IMAGE = "quay.io/centos7/postgresql-13-centos7:latest"
    POSTGRESQL_DATA_DIR = "/tmp/data"
    POSTGRESQL_DOCKER_DBNAME = "hpo-database"

    def start_postgres(self):
        isExist = os.path.exists(self.POSTGRESQL_DATA_DIR)
        if not isExist:
            os.mkdir(self.POSTGRESQL_DATA_DIR)

        command = f"docker run --name hpo-database --rm -d -e POSTGRESQL_USER={self.POSTGRESQL_USER} -e POSTGRESQL_PASSWORD={self.POSTGRESQL_PASSWORD} -e POSTGRESQL_DATABASE={self.POSTGRESQL_DATABASE} -p 5432:{self.POSTGRESQL_PORT} -v {self.POSTGRESQL_DATA_DIR}:/var/lib/postgresql/data {self.POSTGRESQL_IMAGE}"
        subprocess.run(command, shell=True)

    def stop_postgres(self):
        command = f"docker stop {self.POSTGRESQL_DOCKER_DBNAME}"
        subprocess.run(command, shell=True)

instance: POSTGRESQL_DB = POSTGRESQL_DB()

