#!/bin/bash

# Sets up environment for running feed in a dockerized environment
groupadd -g ${GID} -o ${UNAME}
useradd -m -d /htapps/babel/feed -u ${UID} -g ${GID} -o -s /bin/bash ${UNAME}

for i in $(seq 1 24);
  do ln -s /sdr/$i /sdr$i;
done

su -w HTFEED_CONFIG - $UNAME -c "/usr/bin/perl -w /htapps/babel/feed/bin/feed_single_thread.pl -level INFO -screen -dbi"

