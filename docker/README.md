The base image needs to be built first. To build the base image:

`docker build -t hathitrust/feed_base:stretch base/`

To build the jhove-1.6 image:

`docker build -t hathitrust/feed:jhove-1.6 jhove-1.6/

To build the jhove-1.20 image:

`docker build -t hathitrust/feed:jhove-1.20 jhove-1.20/
