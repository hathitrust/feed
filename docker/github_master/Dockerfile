# Checks out feed from git inside the container and configures for image & audio validation

FROM hathitrust/feed_base:buster

RUN git clone https://github.com/hathitrust/feed.git /usr/local/feed
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
COPY config_audio.yaml /usr/local/feed/etc/config_audio.yaml
COPY MDP.pm /usr/local/feed/lib/HTFeed/Namespace/MDP.pm
