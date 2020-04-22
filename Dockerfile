# For local development & testing

FROM hathitrust/feed_base:buster

COPY . /usr/local/feed

WORKDIR /usr/local/feed
RUN cp etc/sample_config/* /usr/local/feed/etc/config
RUN cp etc/sample_namespace/TEST.pm /usr/local/feed/lib/HTFeed/Namespace/TEST.pm
