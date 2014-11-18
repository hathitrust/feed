#!/bin/bash

BASE=/htprep/datasets/full_set/obj
OUTFILE=$BASE/rsync_points

cd $BASE
rm -f $OUTFILE

declare -A NS_DEPTH=( ["aeu"]="8"  \
                      ["bc"]="8"  \
                      ["chi"]="2"  \
                      ["coo"]="5"  \
                      ["dul1"]="2" \
                      ["gri"]="8" \
                      ["hvd"]="2"  \
                      ["ien"]="5"  \
                      ["inu"]="5"  \
                      ["keio"]="4"  \
                      ["loc"]="8"  \
                      ["mdp"]="5"  \
                      ["miua"]="2" \
                      ["miun"]="2" \
                      ["nc01"]="2" \
                      ["ncs1"]="2" \
                      ["njp"]="5"  \
                      ["nnc1"]="3" \
                      ["nnc2"]="8" \
                      ["nyp"]="5"  \
                      ["psia"]="8"  \
                      ["pst"]="4"  \
                      ["pur1"]="5" \
                      ["uc1"]="3"  \
                      ["uc2"]="8"  \
                      ["ucm"]="3"  \
                      ["ucw"]="8"  \
                      ["ufl1"]="8"  \
                      ["uiug"]="5" \
                      ["uiuo"]="8" \
                      ["uma"]="8"  \
                      ["umn"]="5"  \
                      ["usu"]="5"  \
                      ["uva"]="3"  \
                      ["wu"]="3"   \
                      ["yale"]="5" )

for NS in `ls -d */|sed "s/\/$//"`; do
  echo $NS
  if [ ${NS_DEPTH["$NS"]} ]; then
    find ${NS} -maxdepth ${NS_DEPTH["$NS"]} -mindepth ${NS_DEPTH["$NS"]} >> $OUTFILE
  else
    find ${NS} -maxdepth 3 -mindepth 3 >> $OUTFILE
  fi
done
