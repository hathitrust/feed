FROM hathitrust/feed_base:buster
LABEL org.opencontainers.image.source https://github.com/hathitrust/feed

RUN apt-get update && apt-get install -y \
    awscli \
    epubcheck \
    libclamav-client-perl \
    libswitch-perl \
    libtest-class-perl \
    libtest-mockobject-perl \
    libtest-most-perl \
    libtest-spec-perl \
    netcat

ARG UNAME=ingest
ARG UID=1000
ARG GID=1000

RUN groupadd -g $GID -o $UNAME
RUN useradd -m -d /usr/local/feed -u $UID -g $GID -o -s /bin/bash $UNAME

USER $UID:$GID

RUN mkdir -p /tmp/stage/grin
RUN mkdir -p /tmp/prep/toingest /tmp/prep/failed /tmp/prep/ingested /tmp/prep/logs /tmp/prep/toingest/emma

COPY ./docker/aws /usr/local/feed/.aws
WORKDIR /usr/local/feed

RUN mkdir /usr/local/feed/bin /usr/local/feed/src
COPY ./src/validateCache.cpp /usr/local/feed/src/validateCache.cpp
RUN /usr/bin/g++ -o bin/validateCache src/validateCache.cpp -lxerces-c

COPY . /usr/local/feed
COPY ./etc/sample_namespace/TEST.pm /usr/local/feed/etc/namespaces/TEST.pm

ARG version=feed-development
ENV VERSION=$version
