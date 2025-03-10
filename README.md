HathiTrust Ingest Toolkit

![Run CI](https://github.com/hathitrust/feed/actions/workflows/ci.yml/badge.svg)
![Docker Build](https://github.com/hathitrust/feed/actions/workflows/build.yml/badge.svg)

```bash
git clone https://github.com/hathitrust/feed
cd ingest
docker compose build
```

# Development

Running tests:
```
docker compose run test
```

Running specific tests and/or getting prettier output:
```
# Runs all tests
docker compose run test prove
# Run a specific set of tests
docker compose run test prove t/storage.t
# Get more verbose output from a specific test
docker compose run test perl t/storage.t
```

## Validating volumes

* Put volumes in `volumes_to_test/`

```bash
docker compose run validate
```

## Validating a single image

Given a single TIFF or JPEG2000 image, follow these instructions to create a
test "volume" containing only the single image:

* Name the image `00000001.jp2` or `00000001.tif`
* Create a file called `meta.yml` with the following contents:

```yaml
capture_date: 2022-01-01T00:00:00Z
scanner_user: Bob's Book Barn
```

(filling in appropriate values for `capture_date` and `scanner_user`)

* Create a checksum file; e.g. on Linux:

```bash
md5sum meta.yml 00000001.* > checksum.md5`
```

* Zip up the files; e.g. on Linux:"

```bash
zip test_volume.zip 00000001.* checksum.md5 meta.yml
```

* Put the file in `volumes_to_test/`

* Run `docker compose run validate`

## Testing with RClone

Configure rclone as usual, adding a remote called `dropbox`:

```bash
rclone config create dropbox dropbox
```

`docker-compose.yml` will mount your `rclone.conf` inside the container as
`/usr/local/feed/etc/rclone.conf`.

