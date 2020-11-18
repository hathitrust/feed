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

COPY . /usr/local/feed
WORKDIR /usr/local/feed
RUN bin/setup_dev.sh
RUN ln -sf /usr/local/feed/t/fixtures/UNDAMAGED /tmp/prep/UNDAMAGED
RUN ln -sf /usr/local/feed/t/fixtures/DAMAGED /tmp/prep/DAMAGED
