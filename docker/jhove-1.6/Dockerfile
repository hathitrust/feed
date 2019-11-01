FROM hathitrust/feed_base:stretch

COPY jessie-jhove.pref /etc/apt/preferences.d/jessie-jhove.pref
COPY jessie.list /etc/apt/sources.list.d/jessie.list
RUN apt-get update
RUN apt-get install -y jhove

COPY config_audio.yaml /usr/local/feed/etc/config_audio.yaml
COPY MDP.pm /usr/local/feed/lib/HTFeed/Namespace/MDP.pm

