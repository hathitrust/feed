FROM debian:stretch

RUN apt-get update && apt-get install -y \
  openjdk-8-jdk-headless \
  perl \
  imagemagick \
  libxerces-c3.1 \
  libxerces-c3-dev \
  sqlite3 \
  libalgorithm-diff-xs-perl \
  libany-moose-perl \
  libapache-session-perl \
  libarchive-zip-perl \
  libcgi-application-perl \
  libcgi-compile-perl \
  libcgi-emulate-psgi-perl \
  libcgi-psgi-perl \
  libclass-accessor-perl \
  libclass-c3-perl \
  libclass-data-accessor-perl \
  libclass-data-inheritable-perl \
  libclass-errorhandler-perl \
  libclass-load-perl \
  libcommon-sense-perl \
  libcompress-raw-zlib-perl \
  libconfig-auto-perl \
  libconfig-inifiles-perl \
  libconfig-tiny-perl \
  libcrypt-openssl-random-perl \
  libcrypt-openssl-rsa-perl \
  libcrypt-ssleay-perl \
  libdata-optlist-perl \
  libdata-page-perl \
  libdate-calc-perl \
  libdate-manip-perl \
  libdbd-mock-perl \
  libdbd-mysql-perl \
  libdbd-sqlite3-perl \
  libdevel-globaldestruction-perl \
  libdigest-sha-perl \
  libemail-date-format-perl \
  libencode-locale-perl \
  liberror-perl \
  libeval-closure-perl \
  libfcgi-perl \
  libfcgi-procmanager-perl \
  libfile-listing-perl \
  libfile-slurp-perl \
  libfilesys-df-perl \
  libgeo-ip-perl \
  libhtml-parser-perl \
  libhtml-tree-perl \
  libhttp-browserdetect-perl \
  libhttp-cookies-perl \
  libhttp-daemon-perl \
  libhttp-date-perl \
  libhttp-dav-perl \
  libhttp-message-perl \
  libhttp-negotiate-perl \
  libimage-exiftool-perl \
  libimage-info-perl \
  libimage-size-perl \
  libinline-perl \
  libio-html-perl \
  libio-socket-ssl-perl \
  libio-string-perl \
  libipc-run-perl \
  libjson-perl \
  libjson-pp-perl \
  libjson-xs-perl \
  liblist-compare-perl \
  liblist-moreutils-perl \
  liblog-log4perl-perl \
  liblwp-authen-oauth2-perl \
  liblwp-mediatypes-perl \
  libmail-sendmail-perl \
  libmailtools-perl \
  libmime-lite-perl \
  libmime-types-perl \
  libmodule-implementation-perl \
  libmodule-runtime-perl \
  libmoose-perl \
  libmouse-perl \
  libmro-compat-perl \
  libnet-dns-perl \
  libnet-http-perl \
  libnet-libidn-perl \
  libnet-oauth-perl \
  libnet-ssleay-perl \
  libpackage-deprecationmanager-perl \
  libpackage-stash-perl \
  libparse-recdescent-perl \
  libplack-perl \
  libpod-simple-perl \
  libproc-processtable-perl \
  libreadonly-perl \
  libreadonly-xs-perl \
  libroman-perl \
  libsoap-lite-perl \
  libspreadsheet-writeexcel-perl \
  libsub-exporter-progressive-perl \
  libsub-name-perl \
  libtemplate-perl \
  libterm-readkey-perl \
  libterm-readline-gnu-perl \
  libtest-requiresinternet-perl \
  libtest-simple-perl \
  libtie-ixhash-perl \
  libtimedate-perl \
  libtry-tiny-perl \
  libuniversal-require-perl \
  liburi-encode-perl \
  libuuid-perl \
  libuuid-tiny-perl \
  libversion-perl \
  libwww-perl \
  libwww-robotrules-perl \
  libxml-dom-perl \
  libxml-libxml-perl \
  libxml-libxslt-perl \
  libxml-sax-perl \
  libxml-simple-perl \
  libxml-writer-perl \
  libyaml-appconfig-perl \
  libyaml-libyaml-perl \
  libyaml-perl \
  perlmagick

RUN apt-get install -y \
  autoconf \
  bison \
  build-essential \
  git \
  libffi-dev \
  libgdbm-dev \
  libncurses5-dev \
  libreadline6-dev \
  libsqlite3-dev \
  libssl-dev \
  libyaml-dev \
  openssh-server \
  unzip \
  wget \
  zlib1g-dev

RUN cpan \
  File::Value \
  File::ANVL \
  File::Namaste \
  File::Pairtree \
  CGI::Application::Plugin::Routes \
  Algorithm::LUHN \
  OAuth::Lite \
  EBook::EPUB \
  Sub::Uplevel \
  Test::Exception \
  Devel::Cycle \
  Test::Memory::Cycle \
  Mozilla::CA

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
