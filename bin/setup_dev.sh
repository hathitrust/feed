#!/bin/bash

cp -n etc/sample_config/* /usr/local/feed/etc/config
cp etc/sample_namespace/TEST.pm /usr/local/feed/lib/HTFeed/Namespace/TEST.pm
perl Makefile.PL
