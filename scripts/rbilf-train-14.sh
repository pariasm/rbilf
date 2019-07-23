#!/bin/bash
# Runs the rbilf-seq-gt.sh on a training set consisting of 14
# rgb sequences of 20 frames, and returns the MSE over the 
# dataset

# input arguments
s=$1                       # noise level
output=${2:-"trials"}      # output folder
b1prms=${3:-"-v 0"}       # bilateral filter parameters (see bin/rbilf --help)
ofprms=${4:-"tvl1flow 1 0.4"} # optical flow parameters (see bin/rbilf-seq.sh)

# path to training sequences
sf='/home/pariasm/denoising/data/train-14/dataset-rgb/'
#sf='/home/pariasm/denoising/data/train-14/dataset/'

# list of training sequences
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

# create output folder
folder="$output/tmp/"
mkdir -p $folder

b2prms="no" # only one denoising iteration
#T=$BIN/msrbilf-seq-gt.sh
T=$BIN/rbilf-seq-gt.sh
for seq in ${seqs[@]}; do
	echo "$T ${sf}${seq}/%03d.png $ff $lf $s $folder/$seq \"$b1prms\" \
		\"$b2prms\" \"$ofprms\"" >> $folder/${seq}-log
	echo "$T ${sf}${seq}/%03d.png $ff $lf $s $folder/$seq \"$b1prms\" \
		\"$b2prms\" \"$ofprms\" > $folder/${seq}-out"
#		\"$b2prms\" \"$ofprms\" \"$mprms\" > $folder/${seq}-out"
done | parallel

# compute MSE by averaging the mse of each sequence
mse=0
nseqs=${#seqs[@]}
for seq in ${seqs[@]}; do
	out=$(cat $folder/${seq}-out)
	mse=$(echo "$mse + $out/$nseqs" | bc -l)
done
echo $mse

# remove optical flow and occlusion masks, so that they are recomputed
#for seq in ${seqs[@]}; do
#	rm $folder/$seq/bflo*.flo
#	rm $folder/$seq/bocc*.png
#done




# old stuff ###############################################################

## # filter parameters, first step
## #b1_whx0=83
## #b1_whd0=0.92
## b1_whx0=23.6 # 48.6 # 110 # noise 40, rgb, seed2
## b1_whd0=1.8  # 2    # 2   # noise 40, rgb, seed2
## b1_whx=24
## b1_whd=1.6
## b1_wht=14
## b1_thx=0.05
## b1_lambdax=0.1
## b1_lambdat=0.5
## 
## # filter parameters, second step
## b2_whx0=27
## b2_whd0=3.5
## b2_whx=24
## b2_whd=1.6
## b2_wht=14
## b2_thx=0.05
## b2_lambdax=0.1
## b2_lambdat=0.5


## # override default params
## 
## b1_whx=$3
## b1_whd=$4
## b1_lambdax=$5
## b1_wht=$6
## b1_lambdat=$7

## b1prms=$(printf -- "--whx0 %.20f --whd0 %.20f " $b1_whx0 $b1_whd0)
## b1prms+=$(printf -- "--whx %.20f --whd %.20f " $b1_whx $b1_whd)
## b1prms+=$(printf -- "--wthx %.20f --lambdax %.20f " $b1_thx $b1_lambdax) 
## b1prms+=$(printf -- "--wht %.20f --lambdat %.20f -v 0" $b1_wht $b1_lambdat)


## f_dw=${13}
#f_dw=$8
#fprms=$(printf "tvl1flow %d %.20f" $f_sc $f_dw)

## f_sc=0
## f_alpha=$8
## f_gamma=$9
## fprms=$(printf "rof %d %.20f %.20f" $f_sc $f_alpha $f_gamma )

