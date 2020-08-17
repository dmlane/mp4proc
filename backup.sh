#!/bin/bash

video_user="$(my_print_defaults -s videos)"
admin_user="$(my_print_defaults -s admin)"

echo Exporting
mysqldump $admin_user videos >/tmp/videos.dump 
if [ $? -ne 0 ] ; then
	echo Export failed
	exit 1
fi
bn=~/BACKUP/videos.$(date +"%Y%m%d-%H%M%S").sql
link=~/BACKUP/videos-latest.sql
mv  /tmp/videos.dump $bn
ln -sf $bn $link
test -z "$1" ||ln -s $bn ~/BACKUP/videos.$1.sql


#episode
#lookup_status
#orphan_mp4
#outliers
#program
#raw_file
#section
#series
#durations
#episode_status
#videos
#
#echo Importing
#mysql $admin_user test </tmp/videos.dump || echo Import failed
#echo Done
