#!/bin/bash
# Runs nlkalman filtering frame by frame

SEQ=$1 # filtered sequence path
FFR=$2 # first frame
LFR=$3 # last frame
SIG=$4 # noise standard dev.
OUT=$5 # output folder
PM1=$6 # filtering parameters iteration 1
PM2=$7 # filtering parameters iteration 2
OPM=${8:-"1 0.40"} # optical flow parameters

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

# filter first frame {{{1
DEN1="$OUT/den1-%03d.tif"
DEN2="$OUT/den2-%03d.tif"

i=$FFR
NLK="$DIR/rbilf"
$NLK -i $(printf $SEQ $i) -s $SIG $PM1 --den1 $(printf $DEN1 $i) 
$NLK -i $(printf $SEQ $i) -s $SIG $PM2 --gui1 $(printf $DEN1 $i) \
                                       --den1 $(printf $DEN2 $i) 

# filter rest of sequence {{{1
TVL1="$DIR/tvl1flow"

read -ra O <<< "$OPM"
FSCALE=${O[0]}; DW=${O[1]}; TH=${O[2]}; NPROC=2

FLOW="$OUT/bflo-%03d.flo"

for i in $(seq $((FFR+1)) $LFR);
do

	# compute backward optical flow {{{2
	file=$(printf $FLOW $i)
	if [ ! -f $file ]; then
		$TVL1 $(printf $SEQ $i) \
		      $(printf $DEN2 $((i-1))) \
		      $file \
		      $NPROC 0.25 0.2 $DW 100 $FSCALE 0.5 5 0.01 0;
	fi

	# run filtering {{{2
	$NLK -i $(printf $SEQ $i) -s $SIG $PM1 -o $(printf $FLOW $i) \
	 --den0 $(printf $DEN2 $((i-1))) --den1 $(printf $DEN1 $i)

	$NLK -i $(printf $SEQ $i) -s $SIG $PM2 -o $(printf $FLOW $i) \
	 --den0 $(printf $DEN2 $((i-1))) --gui1 $(printf $DEN1 $i) \
	 --den1 $(printf $DEN2 $i)

done

# vim:set foldmethod=marker:
