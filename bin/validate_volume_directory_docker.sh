#!/bin/bash

fullpath=$(realpath $1)

docker run --mount type=bind,source=$fullpath,target=/tmp/stage/toingest/test,readonly hathitrust/feed:latest bash -c "/bin/ls /tmp/stage/toingest/test | sed s/.zip// | HTFEED_CONFIG=/usr/local/etc/feed/config_prevalidate.yaml perl -w /usr/local/feed/bin/validate_volume.pl -p simple -n test --no-clean"
