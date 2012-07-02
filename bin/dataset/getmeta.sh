#! /bin/bash

# Grab any completed bundles from irene.
/usr/bin/scp aleph@irene:/exlibris/aleph/mdp_meta_transfer/\*.tar.gz /htprep/datasets/meta/
/usr/bin/ssh aleph@irene /bin/rm -f /exlibris/aleph/mdp_meta_transfer/\*.tar.gz

# Delete any old bundles.
cd /htprep/datasets/meta
for prefix in `/bin/ls -1 *-* | /bin/cut -f 1 -d "-"| /bin/sort | /usr/bin/uniq`; do
  list=(`/bin/ls -1t $prefix*`)
  count=${#list[*]}
  if [ $count -gt 1 ]; then
    for ((i=1;i<$count;i++)); do
      rm -f ${list[$i]}
    done
  fi
done
