#!/usr/bin/env bash

SQL=/tmp/create_databases.sql
function get_user {
	extract="$(my_print_defaults -s $1)"
	export user=$(sed -n 's/^--user=\(.*\)$/\1/p' <<<"$extract")
	export password=$(sed -n 's/^--password=\(.*\)$/\1/p' <<<"$extract")

}



get_user videos
cat >>$SQL<<EOF
create database if not exists videos;
create user if not exists $user@'%' identified by '$password';
grant delete,execute,insert,select,update on videos.* to $user@'%'; 
EOF


