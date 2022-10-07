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
import sys

import rest_service
import threading
import signal
from logger import get_logger

shutdown = threading.Event()
logger = get_logger("hpo-service")

def signal_handler(sig, frame):
    shutdown.set()
signal.signal(signal.SIGINT, signal_handler)

def main():

    logger.info('Starting HPO service')
    if sys.argv[1] == "BOTH":
        import grpc_service
        gRPCservice = threading.Thread(target=grpc_service.serve)
        gRPCservice.daemon = True
        gRPCservice.start()

    restService = threading.Thread(target=rest_service.main)
    restService.daemon = True
    restService.start()

    shutdown.wait()

    logger.info('Shutting down HPO service')

if __name__ == '__main__':
    main()
