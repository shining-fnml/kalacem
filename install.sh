#!/bin/sh
# 	* SETTINGS *
# Uncomment and fill next line if you don't want autodetection on Perl's
# include path (@INC) or if it fails.
# perl_inc=

#	* CODE *

makeman()
{
	if [ `id -u` -ne 0 ] ; then echo "Please run as root">/dev/stderr ; exit 1 ; fi
	if ! which pod2man > /dev/null ; then
		echo "pod2man is missing. Install it and retry." > /dev/stderr
		exit 1
	fi
	man=`find /usr/local -type d -name man | awk '{ print length, $0 }' | sort -n -s | cut -d" " -f2- | head -1`
	if [ "x$man" = "x" ] ; then
		echo "Can't find a suitable location to install the man page." > /dev/stderr
		exit 1
	fi
	mkdir -p $man/man1
	pod2man -s 1 kalacem $man/man1/kalacem.1
}

main()
{

	if [ "x$perl_inc" = "x" ] ; then
		perl_inc=`perl -V | sed -e '1,/ *@INC:/d' | grep 'site_perl$'`
		if [ "x$perl_inc" = "x" ] ; then
			echo "Can't find a suitable location to install perl modules." > /dev/stderr
			exit 1
		fi
	fi
	install kalacem /usr/local/bin
	install -d $perl_inc/Kalacem
	install -m 644 Kalacem/*.pm $perl_inc/Kalacem
}

case "x$1" in
	xman)
		makeman
		;;
	xnoman)
		main
		;;
	*)
		makeman
		main
		;;
esac
