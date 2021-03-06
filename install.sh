#!/usr/bin/env bash

shopt -s expand_aliases
if [ $(uname -s) == Linux ] ; then
	alias cpanm="sudo cpanm"
fi
# Portable way to get real path .......
readlinkf(){ perl -MCwd -e 'print Cwd::abs_path shift' "$1";}

fail() { echo "$1"; exit 1;}
macos() { test $(uname -s) == Darwin;}
function apt_install {
    dpkg -s $1 >/dev/null 2>&1
    test $? -eq 0 && return 0
    echo "Installing $1"
    sleep 1
    test -f /tmp/.install.flag || sudo apt-get update
    touch /tmp/.install.flag
    sudo apt -y install $1
}

function brew_install {
	if [ ! -z "$2" ] ; then
		test -f $2 && return
	fi
	echo "Installing $1"
	sleep 1
	brew install $1
	test "$3" = "link" && brew link $1 --force
	
}
function linux_packages {
	# perldoc can be  a place holder which always fails - CPAN should always 
	# exist, so this should work ....
	apt_install perl-doc 
	apt_install libmariadb-dev
	apt_install ffmpeg
}
function mac_packages {
	test -f /usr/local/bin/brew ||\
		/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
	brew_install mysql-client /usr/local/bin/mysql link
	brew_install ffmpeg /usr/local/bin/ffmpeg 
	brew_install mp4v2 /usr/local/bin/mp4chaps 
	brew_install gpac /usr/local/bin/MP4Box 
}

function perl_install {
	perldoc -l $1 >/dev/null 2>&1
	test $? -eq 0 && return
	echo "Installing perl module $1"
	cpanm $1
}
	
myscript="$(readlinkf $0)"
bindir=$(dirname $myscript)
envdir=${bindir%/bin}/env

if macos ; then
	mac_packages
else
	linux_packages
fi

#-------------------------------------------------------------------------
perl_install DBI
perl_install MP4::Info
perl_install Clipboard
perl_install Const::Fast
perl_install Term::Screen
perl_install Term::Choose
perl_install Term::ReadKey
perl_install DBD::MariaDB
perl_install lib::abs
#perl_install Perl::Critic::Nits
perl_install Moo
perl_install MooX::Singleton
perl_install Params::ValidationCompiler
perl_install Log::Log4perl
perl_install Log::Dispatch::File 

mkdir -pv ~/data ~/LOGS 2>/dev/null

