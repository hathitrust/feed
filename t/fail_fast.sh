# Runs all tests as given:
# E.g. fail_fast.sh *.t
# or   fail_fast.sh *slow.t
# Logs to $out_dir, one outfile per test file.

# Clean out dir
out_dir="/tmp/perltest_results"
mkdir -p "$out_dir"
rm -f "$out_dir/*"

for test_path in $@
do
    test_name=`basename "$test_path"`
    echo "$test_name : $test_path"
    outfile="/tmp/perltest_results/$test_name"
    perl "$test_path" > $outfile
    status=$?
    if [ $status -gt 0 ]; then
        echo "Error at $test_path"
        echo "see $outfile"
        # Stops at 1st error
        exit;
    fi
done
