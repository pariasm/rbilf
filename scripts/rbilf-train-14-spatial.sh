#!/bin/bash
# Run on a training set

# noise level
s=$1

# output folder
output=${2:-"trials"}

# training set folder
sf='/home/pariasm/denoising/data/train-14/dataset-rgb/'

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
b1_whx0=83
b1_whd0=0.92
b1_whx=24
b1_whd=1.6
b1_wht=14
b1_thx=0.05
b1_lambdax=0.1
b1_lambdat=0.5

# filter parameters, second step
b2_whx0=27
b2_whd0=3.5
b2_whx=24
b2_whd=1.6
b2_wht=14
b2_thx=0.05
b2_lambdax=0.1
b2_lambdat=0.5


# override default params
b1_whx0=$3
b1_whd0=$4
b1prms=$(printf -- "--whx0 %.20f --whd0 %.20f " $b1_whx0 $b1_whd0)
b1prms+=$(printf -- "--whx %.20f --whd %.20f " $b1_whx $b1_whd)
b1prms+=$(printf -- "--wthx %.20f --lambdax %.20f " $b1_thx $b1_lambdax) 
b1prms+=$(printf -- "--wht %.20f --lambdat %.20f -v 0" $b1_wht $b1_lambdat)

b2prms="no"

fprms=$(printf "%d %.20f" $f_sc $f_dw)

folder="$output/tmp/"
mkdir -p $folder

T=$BIN/rbilf-seq-gt.sh
for seq in ${seqs[@]}; do
	echo "$T ${sf}${seq}/%03d.png $ff $lf $s $folder/$seq \"$b1prms\" \
		\"$b2prms\" \"$fprms\"" >> $folder/${seq}-log
	echo "$T ${sf}${seq}/%03d.png $ff $lf $s $folder/$seq \"$b1prms\" \
		\"$b2prms\" \"$fprms\" > $folder/${seq}-out"
done | parallel

mse=0
nseqs=${#seqs[@]}
for seq in ${seqs[@]}; do
	out=$(cat $folder/${seq}-out)
	mse=$(echo "$mse + $out/$nseqs" | bc -l)
done
echo $mse
