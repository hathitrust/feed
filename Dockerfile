# For local development & testing

FROM hathitrust/feed_base:buster

RUN apt-get install -y libtest-class-perl libswitch-perl libtest-spec-perl epubcheck netcat libtest-mockobject-perl

RUN mkdir -p /tmp/stage/grin
RUN mkdir -p /tmp/prep/toingest /tmp/prep/failed /tmp/prep/ingested /tmp/prep/logs /tmp/prep/toingest/emma

COPY . /usr/local/feed
WORKDIR /usr/local/feed
RUN bin/setup_dev.sh
RUN ln -sf /usr/local/feed/t/fixtures/UNDAMAGED /tmp/prep/UNDAMAGED
RUN ln -sf /usr/local/feed/t/fixtures/DAMAGED /tmp/prep/DAMAGED
