#! /bin/bash

# Grab any completed bundles from gimlet.
/usr/bin/scp aleph@gimlet:/aleph-20_1/aleph/mdp_meta_transfer/\*.tar.gz /htprep/datasets/meta/
/usr/bin/ssh aleph@gimlet /bin/rm -f /aleph-20_1/aleph/mdp_meta_transfer/\*.tar.gz

# New format, used first on bib-only ht_all.
/usr/bin/scp aleph@gimlet:/aleph-20_1/aleph/mdp_meta_transfer/\*.json.gz /htprep/datasets/meta/
/usr/bin/ssh aleph@gimlet /bin/rm -f /aleph-20_1/aleph/mdp_meta_transfer/\*.json.gz

# Delete any old bundles.
cd /htprep/datasets/meta
for prefix in `/bin/ls -1 *-* | /bin/cut -f 1 -d "-"| /bin/sort | /usr/bin/uniq`; do
  list=(`/bin/ls -1t $prefix-*`)
  count=${#list[*]}
  if [ $count -gt 1 ]; then
    for ((i=1;i<$count;i++)); do
      rm -f ${list[$i]}
    done
  fi
done

# Refresh special case symlink for ht_all bib data.
rm -f /htprep/datasets/ht_all/obj/meta.json.gz
ln -s /htprep/datasets/meta/ht_all*.gz /htprep/datasets/ht_all/obj/meta.json.gz
