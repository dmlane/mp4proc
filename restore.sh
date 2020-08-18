#!/bin/bash

video_user="$(my_print_defaults -s videos)"
admin_user="$(my_print_defaults -s admin)"

link=~/BACKUP/videos-latest.sql
test -z "$1" || link=$1
if [ ! -f $link ] ;then
	echo $link does not exist
	exit 1
fi

echo Importing
#mysql $admin_user videos <$link || echo Import failed
mysql $admin_user test <$link || echo Import failed
echo Done
