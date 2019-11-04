The base image needs to be built first. To build the base image:

`docker build -t hathitrust/feed_base:buster base/`

Validation with jhove 1.20 (preferred):
`docker build -t hathitrust/feed:jhove-1.20 jhove-1.20/`

Validation with jhove 1.6 (deprecated):
`docker build -t hathitrust/feed:jhove-1.6 jhove-1.6/
