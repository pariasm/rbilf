#!/bin/bash
# Run on a training set

# noise level
s=$1

# output folder
output=${2:-"trials"}

# training set folder
sf='/home/pariasm/Remote/lime/denoising/data/train-14/dataset/'

# test sequences
seqs=(\
boxing \
choreography \
demolition \
grass-chopper \
inflatable \
juggle \
kart-turn \
lions \
ocean-birds \
old_town_cross \
snow_mnt \
swing-boy \
varanus-tree \
wings-turn \
)

ff=1 # first frame
lf=1 # last frame

# we assume that the binaries are in the same folder as the script
BIN=$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )

# default parameters

# optical flow parameters
f_sc=1
f_dw=0.4

# filter parameters, first step
b1_whx=24
b1_wht=14
b1_whd=1.6
b1_thx=0.05
b1_lambdax=0.1
b1_lambdat=0.5

# filter parameters, second step
b2_whx=24
b2_wht=14
b2_whd=1.6
b2_thx=0.05
b2_lambdax=0.1
b2_lambdat=0.5


# override default params

b1_whx=$3
b1_whd=$4
#b1_wht=$5
#b1_lambdax=$6
#b1_lambdat=$7

b1prms=$(printf -- "--whx %.20f --wht %.20f --whd %.20f --wthx %.20f --lambdax %.20f --lambdat %.20f -v 0" \
	$b1_whx $b1_wht $b1_whd $b1_thx $b1_lambdax $b1_lambdat)

b2_whx=$5
b2_whd=$6
#b2_wht=${10}
#b2_lambdax=${11}
#b2_lambdat=${12}

b2prms="no"
b2prms=$(printf -- "--whx %.20f --wht %.20f --whd %.20f --wthx %.20f --lambdax %.20f --lambdat %.20f -v 0" \
	$b2_whx $b2_wht $b2_whd $b2_thx $b2_lambdax $b2_lambdat)

ms_sc=3
ms_rf=$7
mprms=$(printf "%.20f %d" $ms_rf $ms_sc)

#f_dw=${13}
fprms=$(printf "%d %.20f" $f_sc $f_dw)

folder="$output/tmp/"
mkdir -p $folder

T=$BIN/msrbilf-seq-gt.sh
for seq in ${seqs[@]}; do
	echo "$T ${sf}${seq}/%03d.png $ff $lf $s $folder/$seq \"$b1prms\" \"$b2prms\" \"$fprms\" \"$mprms\" > $folder/${seq}-out"
done | parallel

mse=0
nseqs=${#seqs[@]}
for seq in ${seqs[@]}; do
	out=$(cat $folder/${seq}-out)
	mse=$(echo "$mse + $out/$nseqs" | bc -l)
done
echo $mse

# remove optical flow and occlusion masks, so that they are recomputed
rm $folder/$seq/*.flo

