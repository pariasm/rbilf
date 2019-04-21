#!/bin/bash
# Runs nlkalman filtering frame by frame

SEQ=$1 # sequence path
FFR=$2 # first frame
LFR=$3 # last frame
SIG=$4 # noise standard dev.
OUT=$5 # output folder
PM1=$6 # filtering parameters iteration 1
PM2=$7 # filtering parameters iteration 2
OPM=${8:-"1 0.40"} # optical flow parameters
PYR_REC=${9:-0.7}  # recomposition ratio
PYR_LVL=${10:--1}  # number of scales
PYR_DWN=${11:-2}   # downsampling factor

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

# determine number of levels based on the image size
if [ $PYR_LVL -eq -1 ];
then
	PIXELS=$(imprintf "%N" $(printf $SEQ $FFR))
	printf -v PIXELS "%.f" "$PIXELS"
	echo $PIXELS
	if   [ ${PIXELS} -lt  500000 ]; then PYR_LVL=1
	elif [ ${PIXELS} -lt 2000000 ]; then PYR_LVL=2
	elif [ ${PIXELS} -lt 8000000 ]; then PYR_LVL=3
	else                                 PYR_LVL=4
	fi
fi

#echo "Scales: $PYR_LVL"

# create output folder
mkdir -p $OUT

# multiscale filtering {{{1
NLKF="$DIR/rbilf"
TVL1="$DIR/tvl1flow"
DECO="$DIR/decompose"
RECO="$DIR/recompose"
read -ra O <<< "$OPM"
FSCALE=${O[0]}; DW=${O[1]}; NPROC=2
for i in $(seq $FFR $LFR);
do
#	echo filtering frame $i

	# compute pyramid
	$DECO $(printf "$SEQ" $i) "$OUT/ms" $PYR_LVL "-"$(printf %03d.tif $i)
	if [ $i -gt $FFR ]; then
		$DECO "$OUT/den1-"$(printf %03d.tif $((i-1))) "$OUT/ma" $PYR_LVL "-den1-"$(printf %03d.tif $((i-1)))
		$DECO "$OUT/den2-"$(printf %03d.tif $((i-1))) "$OUT/ma" $PYR_LVL "-den2-"$(printf %03d.tif $((i-1)))
	fi

	for ((l=PYR_LVL-1; l>=0; --l))
	do
		NSY=$(printf "$OUT/ms%d-%03d.tif"       $l $i)
		F11=$(printf "$OUT/ms%d-den1-%03d.tif"  $l $i)
		F21=$(printf "$OUT/ms%d-den2-%03d.tif"  $l $i)
		LSIG=$(bc <<< "scale=2; $SIG / ${PYR_DWN}^$l")

		if [ $i -gt $FFR ]; then
#			F10=$(printf "$OUT/ms%d-den1-%03d.tif" $l $((i-1)))
#			F20=$(printf "$OUT/ms%d-den2-%03d.tif" $l $((i-1)))
			F10=$(printf "$OUT/ma%d-den1-%03d.tif" $l $((i-1)))
			F20=$(printf "$OUT/ma%d-den2-%03d.tif" $l $((i-1)))
			FLW=$(printf "$OUT/ms%d-bflo-%03d.flo" $l $i)

			# compute backward optical flow {{{2
			if [ ! -f $FLW ]; then
				$TVL1 $NSY $F20 $FLW 0 0.25 0.2 $DW 100 $FSCALE 0.5 5 0.01 0;
			fi

			# run filtering {{{2
			$NLKF -i $NSY -s $LSIG $PM1 -o $FLW --den0 $F20 --den1 $F11
			$NLKF -i $NSY -s $LSIG $PM2 -o $FLW --den0 $F20 --gui1 $F11 --den1 $F21
		else
			# run filtering {{{2
			$NLKF -i $NSY -s $LSIG $PM1 --den1 $F11
			$NLKF -i $NSY -s $LSIG $PM2 --gui1 $F11 --den1 $F21
		fi
	done

#	MSF1="$OUT/den1-"$(printf %03.1f-%03d.tif $PYR_REC $i)
#	MSF2="$OUT/den2-"$(printf %03.1f-%03d.tif $PYR_REC $i)
	MSF1="$OUT/den1-"$(printf %03d.tif $i)
	MSF2="$OUT/den2-"$(printf %03d.tif $i)
	$RECO "$OUT/ms" $PYR_LVL "-den1-"$(printf %03d.tif $i) $MSF1 -c $PYR_REC
	$RECO "$OUT/ms" $PYR_LVL "-den2-"$(printf %03d.tif $i) $MSF2 -c $PYR_REC
done

# vim:set foldmethod=marker:
