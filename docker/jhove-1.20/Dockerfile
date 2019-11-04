FROM hathitrust/feed_base:buster

RUN sed -i 's/main.*/main contrib non-free/' /etc/apt/sources.list
RUN apt-get update
RUN apt-get install -y jhove

