#!/bin/bash
# Runs nlkalman filtering frame by frame

SEQ=$1 # filtered sequence path
FFR=$2 # first frame
LFR=$3 # last frame
SIG=$4 # noise standard dev.
OUT=$5 # output folder
PM1=$6 # filtering parameters iteration 1
PM2=$7 # filtering parameters iteration 2
OPM=${8:-"tvl1flow 1 0.40"} # optical flow parameters

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

mkdir -p $OUT

# filter first frame {{{1
DEN1="$OUT/den1-%03d.tif"
if [[ $PM2 != "no" ]]; then
	DEN2="$OUT/den2-%03d.tif"
else
	DEN2=$DEN1
fi

i=$FFR
NLK="$DIR/rbilf"
$NLK -i $(printf $SEQ $i) -s $SIG $PM1 --den1 $(printf $DEN1 $i)
if [[ $PM2 != "no" ]]; then
	$NLK -i $(printf $SEQ $i) -s $SIG $PM2 --gui1 $(printf $DEN1 $i) \
	                                       --den1 $(printf $DEN2 $i)
fi

# configure optical flow method {{{1
read -ra O <<< "$OPM"
OFBIN="$DIR/${O[0]}"

NPROC=2
case ${O[0]} in
	"tvl1flow")
		FSCALE=${O[1]}; DW=${O[2]};
		OFPRMS="$NPROC 0 $DW 0 0 $FSCALE";;
		# nproc tau lambda theta nscales fscale zfactor nwarps epsilon verbos
	"phsflow")
		FSCALE=${O[1]}; ALPHA=${O[2]};
		OFPRMS="$NPROC $ALPHA 0 $FSCALE";;
		# nproc alpha nscales fscale zfactor nwarps TOL maxiter verbose
	"rof")
		FSCALE=${O[1]}; ALPHA=${O[2]}; GAMMA=${O[3]};
		OFPRMS="$NPROC $ALPHA $GAMMA 10 $FSCALE 0.5 1e-4 1 8";;
		# nproc alpha gamma nscales fscale zfactor TOL inner_iter outer_iter verbose
	"rdpof")
		FSCALE=${O[1]}; ALPHA=${O[2]}; GAMMA=${O[3]};
		OFPRMS="$NPROC 3 $ALPHA $GAMMA 0 10 $FSCALE 0.5 1e-4 1 8";;
		# nproc method alpha gamma lambda nscales fscale zfactor TOL i_iter o_iter verbose
	* )
		echo ERROR: unknown optical flow $OFBIN
		exit 1;;
esac

FLOW="$OUT/bflo-%03d.flo"
OCCL="$OUT/bocc-%03d.png"

# filter rest of sequence {{{1
for i in $(seq $((FFR+1)) $LFR);
do

	# compute backward optical flow {{{2
	file=$(printf $FLOW $i)
#	if [ ! -f $file ]; then
		$OFBIN $(printf $SEQ $i) $(printf $DEN2 $((i-1))) $file $OFPRMS
#	fi

	# backward occlusion masks {{{2
	file=$(printf $OCCL $i)
#	if [ ! -f $file ]; then
		plambda $(printf $FLOW $i) \
		  "x(0,0)[0] x(-1,0)[0] - x(0,0)[1] x(0,-1)[1] - + fabs 0.75 > 255 *" \
		  -o $file
#	fi

	# run filtering {{{2
	$NLK -i $(printf $SEQ $i) -s $SIG $PM1 -o $(printf $FLOW $i) -k $(printf $OCCL $i)\
	 --den0 $(printf $DEN2 $((i-1))) --den1 $(printf $DEN1 $i)

	if [[ $PM2 != "no" ]]; then
	   $NLK -i $(printf $SEQ $i) -s $SIG $PM2 -o $(printf $FLOW $i) -k $(printf $OCCL $i)\
	    --den0 $(printf $DEN2 $((i-1))) --gui1 $(printf $DEN1 $i) \
	    --den1 $(printf $DEN2 $i)
	fi

done

# vim:set foldmethod=marker:
