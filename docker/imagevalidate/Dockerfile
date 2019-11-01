FROM hathitrust/feed_base:stretch

RUN sed -i 's/main.*/main contrib non-free/' /etc/apt/sources.list
RUN apt-get update
RUN apt-get install -y jhove

WORKDIR /tmp
RUN wget https://kakadusoftware.com/wp-content/uploads/2014/06/KDU7A2_Demo_Apps_for_Ubuntu-x86-64_170827.zip
RUN unzip -j -d kakadu KDU7A2_Demo_Apps_for_Ubuntu-x86-64_170827.zip
RUN mv /tmp/kakadu/*.so /usr/local/lib
RUN mv /tmp/kakadu/kdu* /usr/local/bin
RUN echo "/usr/local/lib" > /etc/ld.so.conf.d/kakadu.conf
RUN ldconfig

COPY config_prevalidate.yaml /usr/local/etc/feed/config_prevalidate.yaml
