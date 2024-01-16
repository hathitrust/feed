FROM debian:bullseye
LABEL org.opencontainers.image.source https://github.com/hathitrust/feed

ARG UNAME=ingest
ARG UID=1000
ARG GID=1000
ENV FEED_HOME=/usr/local/feed

RUN sed -i 's/main.*/main contrib non-free/' /etc/apt/sources.list

RUN apt-get update && apt-get install -y --no-install-recommends \
    awscli \
    build-essential \
    clamav \
    cpanminus \
    curl \
    epubcheck \
    git \
    gpg \
    gpg-agent \
    imagemagick \
    libdate-manip-perl \
    libdbd-mysql-perl \
    libdbi-perl \
    libdevel-cover-perl \
    libimage-exiftool-perl \
    libipc-run-perl \
    libjson-xs-perl \
    liblist-compare-perl \
    liblist-moreutils-perl \
    liblog-log4perl-perl \
    libmailtools-perl \
    libmouse-perl \
    libnet-prometheus-perl \
    libreadonly-perl \
    libreadonly-xs-perl \
    libroman-perl \
    libtest-class-perl \
    libtest-mockobject-perl \
    libtest-most-perl \
    libtest-spec-perl \
    libtest-time-perl \
    libssl-dev \
    liburi-perl \
    libwww-perl \
    libxerces-c3.2 \
    libxerces-c3-dev \
    libxml-libxml-perl \
    libyaml-libyaml-perl \
    mp3val \
    netcat \
    openjdk-11-jre-headless \
    perl \
    rclone \
    unzip \
    zip

RUN curl https://hathitrust.github.io/debian/hathitrust-archive-keyring.gpg -o /usr/share/keyrings/hathitrust-archive-keyring.gpg
RUN echo "deb [signed-by=/usr/share/keyrings/hathitrust-archive-keyring.gpg] https://hathitrust.github.io/debian/ bullseye main" > /etc/apt/sources.list.d/hathitrust.list

RUN apt-get update && apt-get install -y grokj2k-tools

RUN cpan -f -i Net::AMQP::RabbitMQ

COPY etc/imagemagick-policy.xml /etc/ImageMagick-6/policy.xml

COPY etc/jhove-auto-install.xml /tmp/jhove-auto-install.xml
RUN curl https://software.openpreservation.org/rel/jhove/1.26/jhove-xplt-installer-1.26.1.jar -o /tmp/jhove-installer.jar
RUN java -jar /tmp/jhove-installer.jar /tmp/jhove-auto-install.xml

RUN groupadd -g $GID -o $UNAME
RUN useradd -m -d $FEED_HOME -u $UID -g $GID -o -s /bin/bash $UNAME

RUN mkdir /extlib
RUN chown $UID:$GID /extlib
ENV PERL5LIB="/extlib/lib/perl5:$FEED_HOME/lib"

COPY ./src/validateCache.cpp /usr/src/validateCache.cpp
RUN /usr/bin/g++ -o /usr/local/bin/validate-cache /usr/src/validateCache.cpp -lxerces-c

USER $UID:$GID

WORKDIR $FEED_HOME

COPY ./Makefile.PL $FEED_HOME/Makefile.PL

RUN cpanm --notest -l /extlib \
  https://github.com/hathitrust/metslib.git@v1.0.1 \
  https://github.com/hathitrust/progress_tracker.git@v0.9.0

RUN cpanm --notest -l /extlib --skip-satisfied --installdeps .

RUN mkdir -p /tmp/stage/grin
RUN mkdir -p /tmp/prep/toingest /tmp/prep/failed /tmp/prep/ingested /tmp/prep/logs /tmp/prep/toingest/emma

RUN mkdir $FEED_HOME/bin $FEED_HOME/src $FEED_HOME/.gnupg
RUN chown $UID:$GID $FEED_HOME/.gnupg
RUN chmod 700 $FEED_HOME/.gnupg

COPY . $FEED_HOME

ARG version=feed-development
ENV VERSION=$version
