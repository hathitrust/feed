#!/bin/bash

fullpath=$(realpath $1)
dir=$(dirname $fullpath)
objid=$(basename $fullpath .zip)

docker run --mount type=bind,source=$dir,target=/tmp/stage/toingest/test,readonly hathitrust/feed:imagevalidate bash -c "HTFEED_CONFIG=/usr/local/etc/feed/config_prevalidate.yaml perl -w /usr/local/feed/bin/validate_volume.pl -1 simple test $objid --no-clean"
