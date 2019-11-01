FROM hathitrust/feed_base:stretch

COPY buster-jhove.pref /etc/apt/preferences.d/buster-jhove.pref
COPY testing.pref /etc/apt/preferences.d/testing.pref
COPY testing.list /etc/apt/sources.list.d/testing.list
RUN apt-get update
RUN apt-get install -y jhove

COPY config_audio.yaml /usr/local/feed/etc/config_audio.yaml
COPY MDP.pm /usr/local/feed/lib/HTFeed/Namespace/MDP.pm

