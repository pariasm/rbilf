#!/bin/bash
# Runs mlnlkalman-seq.sh comparing the output with the ground truth

SEQ=$1 # sequence path
FFR=$2 # first frame
LFR=$3 # last frame
SIG=$4 # noise standard dev.
OUT=$5 # output folder
PM1=${6:-""} # first iteration parameters
PM2=${7:-""} # second iteration parameters
OPM=${8:-"1 0.40"} # optical flow parameters
MPM=${9:-""} # multiscaler parameters

mkdir -p $OUT
OUT=$OUT

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
$DIR/msrbilf-seq.sh "$OUT/%03d.tif" $FFR $LFR $SIG $OUT "$PM1" "$PM2" "$OPM" $MPM

## # psnr for single-scale filter 1 {{{1
## for i in $(seq $FFR $LFR);
## do
## 	MM[$i]=$(psnr.sh $(printf $SEQ $i) $(printf $OUT/"ms0-den1-%03d.tif" $i) m 0 2>/dev/null)
## 	MM[$i]=$(plambda -c "${MM[$i]} sqrt" 2>/dev/null)
## 	PP[$i]=$(plambda -c "255 ${MM[$i]} / log10 20 *" 2>/dev/null)
## done
## 
## echo "DEN1 - Frame RMSE " ${MM[*]}  > $OUT/ss-measures
## echo "DEN1 - Frame PSNR " ${PP[*]} >> $OUT/ss-measures
## 
## # global psnr
## SS=0
## n=0
## for i in $(seq $((FFR+0)) $LFR);
## do
## 	SS=$(plambda -c "${MM[$i]} 2 ^ $n $SS * + $((n+1)) /" 2>/dev/null)
## 	n=$((n+1))
## done
## 
## MSE=$SS
## RMSE=$(plambda -c "$SS sqrt" 2>/dev/null)
## PSNR=$(plambda -c "255 $RMSE / log10 20 *" 2>/dev/null)
## echo "DEN1 - Total RMSE $RMSE" >> $OUT/ss-measures
## echo "DEN1 - Total PSNR $PSNR" >> $OUT/ss-measures

## # psnr for multi-scale filter 1 {{{1
## for i in $(seq $FFR $LFR);
## do
## 	MM[$i]=$(psnr.sh $(printf $SEQ $i) $(printf $OUT/"den1-%03d.tif" $i) m 0 2>/dev/null)
## 	MM[$i]=$(plambda -c "${MM[$i]} sqrt" 2>/dev/null)
## 	PP[$i]=$(plambda -c "255 ${MM[$i]} / log10 20 *" 2>/dev/null)
## done
## 
## echo "DEN1 - Frame RMSE " ${MM[*]}  > $OUT/measures
## echo "DEN1 - Frame PSNR " ${PP[*]} >> $OUT/measures
## 
## # global psnr
## SS=0
## n=0
## for i in $(seq $((FFR+0)) $LFR);
## do
## 	SS=$(plambda -c "${MM[$i]} 2 ^ $n $SS * + $((n+1)) /" 2>/dev/null)
## 	n=$((n+1))
## done
## 
## MSE=$SS
## RMSE=$(plambda -c "$SS sqrt" 2>/dev/null)
## PSNR=$(plambda -c "255 $RMSE / log10 20 *" 2>/dev/null)
## echo "DEN1 - Total RMSE $RMSE" >> $OUT/measures
## echo "DEN1 - Total PSNR $PSNR" >> $OUT/measures


# exit if no smoothing required
if [[ $PM2 == "no" ]]; then printf "%f\n" $MSE; exit 0; fi

## # psnr for single-scale filter 2 {{{1
## for i in $(seq $FFR $LFR);
## do
## 	MM[$i]=$(psnr.sh $(printf $SEQ $i) $(printf $OUT/"ms0-den2-%03d.tif" $i) m 0 2>/dev/null)
## 	MM[$i]=$(plambda -c "${MM[$i]} sqrt" 2>/dev/null)
## 	PP[$i]=$(plambda -c "255 ${MM[$i]} / log10 20 *" 2>/dev/null)
## done
## 
## echo "DEN2 - Frame RMSE " ${MM[*]} >> $OUT/ss-measures
## echo "DEN2 - Frame PSNR " ${PP[*]} >> $OUT/ss-measures
## 
## # global psnr
## SS=0
## n=0
## for i in $(seq $((FFR+0)) $LFR);
## do
## 	SS=$(plambda -c "${MM[$i]} 2 ^ $n $SS * + $((n+1)) /" 2>/dev/null)
## 	n=$((n+1))
## done
## 
## MSE=$SS
## RMSE=$(plambda -c "$SS sqrt" 2>/dev/null)
## PSNR=$(plambda -c "255 $RMSE / log10 20 *" 2>/dev/null)
## echo "DEN2 - Total RMSE $RMSE" >> $OUT/ss-measures
## echo "DEN2 - Total PSNR $PSNR" >> $OUT/ss-measures

# psnr for multi-scale filter 2 {{{1
for i in $(seq $FFR $LFR);
do
	MM[$i]=$(psnr.sh $(printf $SEQ $i) $(printf $OUT/"den2-%03d.tif" $i) m 0 2>/dev/null)
	MM[$i]=$(plambda -c "${MM[$i]} sqrt" 2>/dev/null)
	PP[$i]=$(plambda -c "255 ${MM[$i]} / log10 20 *" 2>/dev/null)
done

echo "DEN2 - Frame RMSE " ${MM[*]} >> $OUT/measures
echo "DEN2 - Frame PSNR " ${PP[*]} >> $OUT/measures

# global psnr
SS=0
n=0
for i in $(seq $((FFR+0)) $LFR);
do
	SS=$(plambda -c "${MM[$i]} 2 ^ $n $SS * + $((n+1)) /" 2>/dev/null)
	n=$((n+1))
done

MSE=$SS
RMSE=$(plambda -c "$SS sqrt" 2>/dev/null)
PSNR=$(plambda -c "255 $RMSE / log10 20 *" 2>/dev/null)
echo "DEN2 - Total RMSE $RMSE" >> $OUT/measures
echo "DEN2 - Total PSNR $PSNR" >> $OUT/measures


printf "%f\n" $MSE

# vim:set foldmethod=marker:
