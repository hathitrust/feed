# bash validate_volume.sh /path/to/item.zip

fullpath=$(realpath $1)
objid=$(basename $fullpath .zip)
test_dir=/tmp/prep/toingest/test/

# Set up working dir and copy input file there
rm    --verbose -rf "$test_dir"
mkdir --verbose -p  "$test_dir"
cp    --verbose     "$fullpath" "$test_dir"

perl /usr/local/feed/bin/validate_volume.pl -1 simple test $objid --clean
