#!/usr/bin/env bash

function fail {
	echo "$*"
	echo "     aborting!"
	exit 2
	}

# Check we have ffmpeg on the path
ffmpeg=$(type -P ffmpeg)
test -z "$ffmpeg" && fail "Cannot find ffmpeg on the path"

os=$(uname -o)

if [ "$os" == "Darwin"] ; then
	NAS_BASE=/System/Volumes/Data
else
	NAS_BASE=/Diskstation
fi
MP4_DIR=$NAS_BASE/Videos/Import

test -d $MP4_DIR || fail "MP4_DIR $MP4_DIR not found"
#---------------------------------------------
n=0
filter=""
while getopts "i:p:S:e:"
do
	case $c in
		i)	inputs="$inputs -i $OPTARG"
			filter="$filter[${n}:v:0] [${n}:a:0] "
			:;;
		p)	program=$OPTARG;;
		S)	series=$OPTARG;;
		e)	episode=$OPTARG;;
	esac
done
shift $((OPTIND-1))
test $# -lt 1 && fail "No output file provided"
output_file=$1
test -z "$program" && fail "No program supplied"
test -z "$series" && fail "No series supplied"
test -z "$episode" && fail "No episode supplied"


SPLIT_FOLDER=~/work/Videos/Split
OUTPUT_FOLDER=~/work/Videos/Processed
WORK_FOLDER=~/work/tmp
preset=medium
crf=22
mkdir -p $SPLIT_FOLDER $OUTPUT_FOLDER $WORK_FOLDER

episode_id=$(( ($series*100)+$episode ))
((series+=0))

title=${output_file%.mp4}

# Define metadata
# 
cat >${SPLIT_FOLDER}/metadata.txt<<EOF
;FFMETADATA1
major_brand=isom
minor_version=512
compatible_brands=isomiso2avc1mp41
title=$title
episode_sort=$episode
show=$program
episode_id=$episode_id
season_number=$series
media_type=10
encoder=Lavf58.20.100
EOF

# Create version without metadata
NoMeta=${WORK_FOLDER}/${title}_noMeta.mp4
rm -f $NoMeta 2>/dev/null

ffmpeg -loglevel warning -y $inputs -filter_complex "$filter" \
		 -map "[v]" -map "[a]" \
		 -c:v libx264 -preset $preset -crf $crf -c:a aac -b:a 160k $NoMeta
if [ $? -ne 0 ] ; then
	return 1
fi

# Add metadata
ffmpeg -i $NoMeta -i ${SPLIT_FOLDER}/metadata.txt -map_metadata 1 -c:v copy -c:a copy ${WORK_FOLDER}/$output_file
if [ $? -ne 0 ] ; then
	return 2
fi

mkdir -p $NAS_BASE/Videos/Processed/$program

mv -f ${WORK_FOLDER}/$output_file $NAS_BASE/Videos/Processed/$program/

if [ $? -ne 0 ] ; then
	return 3
fi
return 0

