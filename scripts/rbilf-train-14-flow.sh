#!/bin/bash
# Run on a training set

# noise level
s=$1

# optical flow parameters
f_dw=$3   # data attachment weight
f_sc=1    # finest scale (this parameter is fixed)

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

ff=1  # first frame
lf=20 # last frame

# we assume that the binaries are in the same folder as the script
BIN=$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )

b1prms="-v 0"
b2prms="no"

folder="$output/tmp/"
mkdir -p $folder

T=$BIN/rbilf-seq-gt.sh
for seq in ${seqs[@]}; do
	echo "$T ${sf}${seq}/%03d.png $ff $lf $s $folder/$seq \"-v 0\" \
		\"no\" \"$fprms\"" >> $folder/${seq}-log
	echo "$T ${sf}${seq}/%03d.png $ff $lf $s $folder/$seq \"-v 0\" \
		\"no\" \"$fprms\" > $folder/${seq}-out"
done | parallel

mse=0
nseqs=${#seqs[@]}
for seq in ${seqs[@]}; do
	out=$(cat $folder/${seq}-out)
	mse=$(echo "$mse + $out/$nseqs" | bc -l)
done
echo $mse
