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
	file=$(printf $OUT/"%03d.tif" $i)
	if [ ! -f $file ]
	then
		export SRAND=$RANDOM;
		awgn $SIG $(printf $SEQ $i) $file
	fi
done

# run denoising script {{{1
$DIR/rbilf-seq.sh "$OUT/%03d.tif" $FFR $LFR $SIG $OUT "$PRM" "$OPM"

# reset first frame for psnr computation {{{1
FFR1=$((FFR+10))

# compute psnr {{{1
SS=0
n=0
for i in $(seq $((FFR1)) $LFR);
do
	m=$(psnr.sh $(printf $SEQ $i) $(printf $OUT/"deno-%03d.tif" $i) m 10 2>/dev/null)
	MM[$i]=$(plambda -c "$m sqrt" 2>/dev/null)
	PP[$i]=$(plambda -c "255 ${MM[$i]} / log10 20 *" 2>/dev/null)
	SS=$(plambda -c "$m $n $SS * + $((n+1)) /" 2>/dev/null)
	n=$((n+1))
done

DMSE=$SS
DRMSE=$(plambda -c "$SS sqrt" 2>/dev/null)
DPSNR=$(plambda -c "255 $DRMSE / log10 20 *" 2>/dev/null)
echo "Frame RMSE " ${MM[*]}  > $OUT/measures
echo "Frame PSNR " ${PP[*]} >> $OUT/measures
echo "Total RMSE $DRMSE" >> $OUT/measures
echo "Total PSNR $DPSNR" >> $OUT/measures

# convert tif to png (to save space) {{{1
for i in $(seq $FFR $LFR);
do
	ii=$(printf %03d $i)
	echo "plambda $OUT/deno-${ii}.tif x -o $OUT/deno-${ii}.png && rm $OUT/deno-${ii}.tif"
done | parallel

printf "%f\n" $DMSE;

# vim:set foldmethod=marker:
