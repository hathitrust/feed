# In its barest form, test a -p simple -n test volume with:
# bash validate_volume.sh -z /path/to/item.zip

# Default args:
clean=""
zip_path=""
debug=""
namespace="test"
packagetype="simple"

# Override default args:
while true; do
    case "$1" in
        -c | --clean ) clean="--clean";        shift 1 ;;
        -d | --debug ) debug="-d";             shift 1 ;;
        -z | --zip_path ) zip_path="$2";       shift 2 ;;
        -n | --namespace ) namespace="$2";     shift 2 ;;
        -p | --packagetype ) packagetype="$2"; shift 2 ;;
        -- ) shift; break ;;
        * )  break ;;
    esac
done

# Check required args:
if [ -z "$zip_path" ]; then
    echo "missing required param -z/--zip_path"
    exit 1
fi

fullpath=$(realpath $zip_path)
objid=$(basename $fullpath .zip)
test_dir=/tmp/prep/toingest/test/

# Set up working dir and copy input file there
rm    --verbose -rf "$test_dir"
mkdir --verbose -p  "$test_dir"
cp    --verbose     "$fullpath" "$test_dir"

# Output the full command & run it
cmd="perl $debug /usr/local/feed/bin/validate_volume.pl -1 $packagetype $namespace $objid $clean"
echo "---"
echo "RUNNING: $cmd"
eval "$cmd"
