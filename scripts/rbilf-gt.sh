#!/bin/bash
# Evals rbilf using ground truth

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
 
# add noise {{{1
for i in $(seq $FFR $LFR);
do
	file=$(printf $OUT/"n%04d.tif" $i)
	if [ ! -f $file ]
	then
		export SRAND=$RANDOM;
		awgn $SIG $(printf $SEQ $i) $file
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
		$TVL1 $(printf $OUT"/n%04d.tif" $i) \
				$(printf $OUT"/n%04d.tif" $((i-1))) \
				$file \
				$NPROC 0.25 0.2 $DW 100 $FSCALE 0.5 5 0.01 0; 
	fi
done
cp $(printf $OUT"/%04d_b.flo" $((FFR+1))) $(printf $OUT"/%04d_b.flo" $FFR)

# run denoising {{{1
echo \
$DIR/rbilf \
 -i $OUT"/n%04d.tif" -o $OUT"/%04d_b.flo" -f $FFR -l $LFR -s $SIG \
 -d $OUT"/d%04d.tif" $PRM
$DIR/rbilf \
 -i $OUT"/n%04d.tif" -o $OUT"/%04d_b.flo" -f $FFR -l $LFR -s $SIG \
 -d $OUT"/d%04d.tif" $PRM

# compute psnr {{{1
for i in $(seq $FFR $LFR);
do
	# we remove a band of 10 pixels from each side of the frame
	MM[$i]=$($DIR/psnr.sh $(printf $SEQ $i) $(printf $OUT/"d%04d.tif" $i) m 10)
	MM[$i]=$(plambda -c "${MM[$i]} sqrt")
	PP[$i]=$(plambda -c "255 ${MM[$i]} / log10 20 *")
done

echo "Frame RMSE " ${MM[*]}  > $OUT/measures
echo "Frame PSNR " ${PP[*]} >> $OUT/measures

# Global measures (from 4th frame)
SS=0
n=0
for i in $(seq $((FFR+3)) $LFR);
do
	SS=$(plambda -c "${MM[$i]} 2 ^ $n $SS * + $((n+1)) /")
	n=$((n+1))
done

RMSE=$(plambda -c "$SS sqrt")
PSNR=$(plambda -c "255 $RMSE / log10 20 *")
echo "Total RMSE $RMSE" >> $OUT/measures
echo "Total PSNR $PSNR" >> $OUT/measures


# vim:set foldmethod=marker:
