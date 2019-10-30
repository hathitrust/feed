FROM hathitrust/feed_base:stretch

# enable non-free section
RUN sed -i 's/main.*/main contrib non-free/' /etc/apt/sources.list
RUN apt-get update
RUN apt-get install -y jhove unzip libdbd-sqlite3-perl

RUN git clone https://github.com/hathitrust/feed_with_history.git /usr/local/feed
WORKDIR /tmp
RUN wget https://kakadusoftware.com/wp-content/uploads/2014/06/KDU7A2_Demo_Apps_for_Ubuntu-x86-64_170827.zip
RUN unzip -j -d kakadu KDU7A2_Demo_Apps_for_Ubuntu-x86-64_170827.zip
RUN mv /tmp/kakadu/*.so /usr/local/lib
RUN mv /tmp/kakadu/kdu* /usr/local/bin
RUN echo "/usr/local/lib" > /etc/ld.so.conf.d/kakadu.conf
RUN ldconfig

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


