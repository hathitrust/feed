HathiTrust Ingest Toolkit (Feed)

[![Build Status](https://travis-ci.org/hathitrust/feed.svg?branch=master)](https://travis-ci.org/hathitrust/feed)

```bash
git clone https://github.com/hathitrust/feed
cd feed
git submodule update --init metslib
docker-compose build
docker-compose run test bin/setup_dev.sh
```

# Development

Start services via Docker if necessary:
```
docker-compose up -d mariadb clamav
```

Then:
```
docker-compose run test make test
```

Running specific tests and/or getting prettier output:
```
# Runs all tests
docker-compose run test prove -I lib 
# Run a specific set of tests
docker-compose run test prove -I lib t/storage.t
# Get more verbose output from a specific test
docker-compose run test perl -I lib t/storage.t
```

Validating volumes

* Put volumes in `volumes_to_test/`

```bash
docker-compose run validate
```
