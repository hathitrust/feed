FROM hathitrust/feed_base:stretch

# enable non-free section
RUN sed -i 's/main.*/main contrib non-free/' /etc/apt/sources.list
RUN apt-get update
RUN apt-get install -y jhove unzip libdbd-sqlite3-perl

RUN git clone https://github.com/hathitrust/feed_with_history.git /usr/local/feed
WORKDIR /usr/local/feed
# other submodules are private
RUN git pull
RUN git submodule init metslib
RUN git submodule update metslib
RUN cp etc/sample_config/* etc/config
RUN cp etc/sample_namespace/TEST.pm etc/namespaces
RUN perl Makefile.PL && make && make install
RUN mkdir -p /tmp/stage/toingest/test

COPY config_prevalidate.yaml /usr/local/etc/feed/config_prevalidate.yaml


