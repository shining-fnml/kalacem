package Kalacem;
use strict;
use warnings;

use constant {
	EC_OK          =>  0,
	EC_FAILURE     =>  1,
	EC_USAGE       => 64,
	EC_DATAERR     => 65,
	EC_NOINPUT     => 66,
	EC_UNAVAILABLE => 69,
	EC_SOFTWARE    => 70,
	EC_CANTCREAT   => 73,
	EC_IOERR       => 74,
	EC_TEMPFAIL    => 75,
	EC_PROTOCOL    => 76,
	EC_NOPERM      => 77,
	EC_CONFIG      => 78,
};

use constant {
	IR_OUTSIDE => -1,
	IR_NO      =>  0,
	IR_YES     =>  1
};

use constant {
	MOD_ERROR   => -1,
	MOD_NONE    =>  0,
	MOD_BOTH    =>  1,
	MOD_LOCAL   =>  2,
	MOD_CENTRAL =>  3,
};

use constant {
	RS_OK		=> 0,	# Repository is ready to read and write
	RS_BADREMOTE	=> 1,	# Configuration file exists but is not readable
	RS_BADCONF	=> 2,	# Configuration file exists but is not readable
	RS_NOWRITE	=> 3,	# Repository is potentially readwrite but not configured for writing
	RS_RO		=> 4,	# Repository is readonly
	RS_NOGIT	=> 5,	# Repository does not point to a git directory
	RS_BADLINK	=> 6,	# Repository is a broken symlink
	RS_BROKEN	=> 6,	# Repository is not a symlink
	RS_MISSING	=> 7,	# Repository is missing
	RS_UNDEFINED	=> 8,	# Before any check
};

sub fatal
{
	fatalEc(EC_FAILURE, @_);
}

sub fatalEc
{
	my $exitCode=shift;

	say STDERR @_;
	exit $exitCode;
}

1;
