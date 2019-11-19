#!/bin/bash

fullpath=$(realpath $1)

docker run --mount type=bind,source=$fullpath,target=/tmp/images_to_validate,readonly hathitrust/feed:latest bash -c "HTFEED_CONFIG=/usr/local/etc/feed/config_prevalidate.yaml perl -w /usr/local/feed/bin/validate_images.pl simple test /tmp/images_to_validate -level DEBUG -screen"
