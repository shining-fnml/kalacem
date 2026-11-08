#!/bin/sh
#       * SETTINGS *
# Uncomment and fill next line if you don't want autodetection on Perl's
# include path (@INC) or if it fails.
# perl_inc=

#       * CODE *

perlmoduledir()
{
        if [ "x$perl_inc" = "x" ] ; then
                # Retrieve the default 'site_perl' directory from Perl's core configuration
                perl_inc=$(perl -MConfig -e 'print $Config{installsitelib}')
                
                # Safe fallback from @INC if Config variable is empty
                if [ "x$perl_inc" = "x" ] ; then
                        perl_inc=$(perl -e 'print (grep(/site_perl/, @INC))')
                fi

                if [ "x$perl_inc" = "x" ] ; then
                        echo "Can't find a suitable location to install perl modules." > /dev/stderr
                        exit 1
                fi
        fi
}

makeman()
{
        if [ "$(id -u)" -ne 0 ] ; then echo "Please run as root" > /dev/stderr ; exit 1 ; fi
        if ! which pod2man > /dev/null 2>&1 ; then
                echo "pod2man is missing. Install it and retry." > /dev/stderr
                exit 1
        fi
        
        # Query Perl for the standard man pages directory (Section 1)
        man1_dir=$(perl -MConfig -e 'print $Config{installsateman1dir}')
        
        # Standard fallback if Perl does not return a valid path
        if [ "x$man1_dir" = "x" ] ; then
                man1_dir="/usr/local/man/man1"
        fi
        
        mkdir -p "$man1_dir"
        pod2man -s 1 kalacem.pl "$man1_dir/kalacem.1"
}

main()
{
        if [ "$(id -u)" -ne 0 ] ; then echo "Please run as root" > /dev/stderr ; exit 1 ; fi

        # Detect the Perl modules directory in a cross-platform way
        perlmoduledir
	echo "perl_inc: $perl_inc"
	exit 0

        # OS-specific dependency management
        if [ -d /etc/apt/sources.list.d ] ; then
                # Debian / Ubuntu
                apt-get update && apt-get install -y libio-prompter-perl liblist-moreutils-perl
        elif [ -e /etc/fedora-release ] ; then
                # Fedora
                dnf install -y perl-IO-Prompter perl-List-MoreUtils
        elif [ -e /etc/freebsd-update.conf ] ; then
                # FreeBSD
		# Workaround for FreeBSD 15.1+: manually require
		# p5-match-simple due to missing dependency in p5-IO-Prompter
		# (Perl 5.42+ smartmatch removal). This may change in other OS
		# versions.
                pkg install -y p5-IO-Prompter p5-match-simple p5-List-MoreUtils
	else
                # Unsupported or unrecognized OS
                echo "NOTICE: Operating system not recognized. Automatic dependency installation skipped." > /dev/stderr
                echo "        Please ensure that 'IO::Prompter' and 'List::MoreUtils' are installed" > /dev/stderr
                echo "        manually via your package manager or CPAN for this program to work." > /dev/stderr
        fi

        # Install the executable and modules
        install kalacem.pl /usr/local/bin/kalacem
        install -d "$perl_inc/Kalacem"
        install -m 644 Kalacem/*.pm "$perl_inc/Kalacem"
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
