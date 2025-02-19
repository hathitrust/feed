# Does what JHOVE_Runner does, on the images in images_to_test/.
# Essentially a shortcut to the actual validation, compared to validate_images.pl.
# Dumps the full xml of the validation.
# Interesting elements to grep in the output include 'status' and 'message'.
# Invocation:
#   docker compose run --rm test bash bin/jhove_image_check.sh
ls -w1 images_to_test | egrep '\.(jp2|tif)$' |
    while read FILENAME;
    do
	/opt/jhove/jhove -h XML -c /opt/jhove/conf/jhove.conf "images_to_test/$FILENAME";
	echo
	echo "---"
	echo
    done;
