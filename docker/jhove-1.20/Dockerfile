FROM hathitrust/feed_base:stretch

COPY buster-jhove.pref /etc/apt/preferences.d/buster-jhove.pref
COPY testing.pref /etc/apt/preferences.d/testing.pref
COPY testing.list /etc/apt/sources.list.d/testing.list
RUN apt-get update
RUN apt-get install -y jhove

RUN mkdir -p /l/local && git clone https://github.com/hathitrust/feed.git /l/local/feed
WORKDIR /l/local/feed
RUN perl Makefile.PL && make && make install

COPY config_audio.yaml /l/local/feed/etc/config_audio.yaml

