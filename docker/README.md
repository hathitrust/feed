The base image needs to be built first. To build the base image:

`docker build -t hathitrust/feed_base:stretch base/`

Image & volume validation:
`docker build -t hathitrust/feed:imagevalidate imagevalidate/`

Audio validation with jhove 1.6:
`docker build -t hathitrust/feed:jhove-1.6 jhove-1.6/

Audio validation with jhove 1.20:

`docker build -t hathitrust/feed:jhove-1.20 jhove-1.20/
