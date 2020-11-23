# For local development & testing

FROM hathitrust/feed_base:buster

RUN apt-get update && apt-get install -y \
    epubcheck \
    libclamav-client-perl \
    libswitch-perl \
    libtest-class-perl \
    libtest-mockobject-perl \
    libtest-spec-perl \
    netcat

RUN mkdir -p /tmp/stage/grin
RUN mkdir -p /tmp/prep/toingest /tmp/prep/failed /tmp/prep/ingested /tmp/prep/logs

WORKDIR /usr/local/feed
