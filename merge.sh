#!/usr/bin/env bash

function usage {
	echo "$0 -i <input_file> -f start_time -t end_time output_file"
	echo "    Where times must be in format HH:MM:SS.nnn"
	exit 1
}
function fail {
	echo "$*"
	echo "     aborting ??????????"
	exit 2
}



# Check we have ffmpeg on the path 
ffmpeg=$(type -P ffmpeg)
test -z "$ffmpeg" && fail "Cannot find ffmpeg on the path"

os=$(uname -o)

if [ "$os" == "Darwin" ] ; then
	NAS_BASE=/System/Volumes/Data
else
	NAS_BASE=/Diskstation
fi
MP4_DIR=$NAS_BASE/Unix/Videos/Import
SPLIT_FOLDER=~/work/Videos/Split

n=0
file_count=0
filter=""
cleanup_list=""
while getopts "i:p:S:e:" c
do
	case $c in
		i)	inputs="$inputs -i $SPLIT_FOLDER/$OPTARG"
			filter="$filter[${file_count}:v:0] [${file_count}:a:0] "
			cleanup_list="$cleanup_list $SPLIT_FOLDER/$OPTARG"
			(( file_count++ ))
			:;;
		p)	program=$OPTARG;;
		S)	series=$OPTARG;;
		e)	episode=$OPTARG;;
	esac
done
shift $((OPTIND-1))
test $# -lt 1 && fail "No output file provided"
test -z "$program" && fail "No program supplied"
test -z "$series" && fail "No series supplied"
test -z "$episode" && fail "No episode supplied"
output_file=$1

#---------------------------------------------------------------------
# Check we have access to NAS 
test -d $MP4_DIR 	|| fail "MP4_DIR $MP4_DIR not found"
PROCDIR=$NAS_BASE/Unix/Videos/Processed/$program
mkdir -p $PROCDIR 	|| fail "Could not create folder $PROCDIR"
flag=${PROCDIR}/$(hostname).flag
echo Hello>$flag 	|| fail "Could not create $flag"
rm -f $flag 		|| fail "Could not remove $flag"

#---------------------------------------------------------------------
echo "Creating $output_file ----------"
OUTPUT_FOLDER=~/work/Videos/Processed
WORK_FOLDER=~/work/tmp
preset=medium
crf=22
mkdir -p $SPLIT_FOLDER $OUTPUT_FOLDER $WORK_FOLDER
filter="${filter}concat=n=$file_count:v=1:a=1 [v] [a]"

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

ffmpeg=$(type -P ffmpeg)

function FFMPEG {
	echo $ffmpeg $@
	$ffmpeg "$@"
}
# Create version without metadata
NoMeta=${WORK_FOLDER}/${title}_noMeta.mp4
work_mp4=${WORK_FOLDER}/work.mp4
rm -f $NoMeta 2>/dev/null
if [ ! -f $NoMeta ] ; then
	FFMPEG -loglevel warning -y $inputs -filter_complex "$filter" \
			 -map "[v]" -map "[a]" \
			 -c:v libx264 -preset $preset -crf $crf -c:a aac -b:a 160k $work_mp4
	test $? -ne 0 && fail "Merge failed"
	mv -v  $work_mp4 $NoMeta
	rm -vf $cleanup_list
fi

# Add metadata
if [ ! -f ${WORK_FOLDER}/$output_file ] ; then
	FFMPEG -i $NoMeta -y -i ${SPLIT_FOLDER}/metadata.txt -map_metadata 1 -c:v copy -c:a copy $work_mp4
	test $? -ne 0 && fail "Failed to add metadata"
	mv -v $work_mp4  ${WORK_FOLDER}/$output_file
fi


mv -fv ${WORK_FOLDER}/$output_file $PROCDIR/ 2>&1

test $? -ne 0 && fail "Unable to move result to $PROCDIR/"
rm -fv $NoMeta
echo "$output_file created successfully ++++++++++"
exit 0

