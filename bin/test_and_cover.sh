#!/bin/bash

bin/wait-for --timeout=300 mariadb:3306 minio:9000 pushgateway:9091 rabbitmq:5672
cover -test -report Coveralls -make 'prove; exit $?'
