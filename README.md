HathiTrust Ingest Toolkit

![Run CI](https://github.com/hathitrust/feed/actions/workflows/ci.yml/badge.svg)
![Docker Build](https://github.com/hathitrust/feed/actions/workflows/build.yml/badge.svg)

```bash
git clone https://github.com/hathitrust/feed
cd ingest
docker-compose build
```

# Development

Running tests:
```
docker-compose run test 
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

## Validating volumes

* Put volumes in `volumes_to_test/`

```bash
docker-compose run validate
```

## Testing with RClone

Configure rclone as usual, adding a remote called `dropbox`:

```bash
rclone config create dropbox dropbox
```

`docker-compose.yml` will mount your `rclone.conf` inside the container as
`/usr/local/feed/etc/rclone.conf`.
