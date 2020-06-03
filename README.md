HathiTrust Ingest Toolkit (Feed)

[![Build Status](https://travis-ci.org/hathitrust/feed.svg?branch=master)](https://travis-ci.org/hathitrust/feed)

```bash
git clone https://github.com/hathitrust/feed
git submodule update --init metslib
docker-compose build
```

Running tests as in continuous integration

```bash
docker-compose run travis_test
```

Development

```bash
docker-compose run test bin/setup_dev.sh
docker-compose run test make test
```

Validating volumes

* Put volumes in volumes_to_test

```bash
docker-compose run validate
```
