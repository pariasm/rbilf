#!/bin/bash
# Computes optical flow and denoises with rbilf

SEQ=$1 # sequence path
FFR=$2 # first frame
LFR=$3 # last frame
SIG=$4 # noise standard dev.
OUT=$5 # output folder
PRM="${6}" # denoiser parameters
OPM=${7:-"1 0.40 0.75 1 0.40 0.75"} # optical flow parameters

#mkdir -p $OUT/s$SIG
#OUT=$OUT/s$SIG
mkdir -p $OUT

# we assume that the binaries are in the same folder as the script
DIR=$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )

# error checking {{{1
for i in $(seq $FFR $LFR);
do
	file=$(printf $SEQ $i)
	if [ ! -f $file ]
	then
		echo ERROR: $file not found
		exit 1
	fi
done

# compute optical flow {{{1
TVL1="$DIR/tvl1flow"

read -ra O <<< "$OPM"
FSCALE=${O[0]}; DW=${O[1]}; NPROC=0
for i in $(seq $((FFR+1)) $LFR);
do
	file=$(printf $OUT"/%04d_b.flo" $i)
	if [ ! -f $file ]
	then
		$TVL1 $(printf $SEQ $i) \
		      $(printf $SEQ $((i-1))) \
		      $file \
		      $NPROC 0.25 0.2 $DW 100 $FSCALE 0.5 5 0.01 0;
	fi
done
cp $(printf $OUT"/%04d_b.flo" $((FFR+1))) $(printf $OUT"/%04d_b.flo" $FFR)

# run denoising {{{1
#echo \
#$DIR/rbilf \
# -i $OUT"/n%04d.tif" -o $OUT"/%04d_b.flo" -f $FFR -l $LFR -s $SIG \
# -d $OUT"/d%04d.tif" $PRM
$DIR/rbilf \
 -i $SEQ -o $OUT"/%04d_b.flo" -f $FFR -l $LFR -s $SIG \
 -d $OUT"/den-%04d.tif" $PRM

# vim:set foldmethod=marker:
