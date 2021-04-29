# Creating parent class
package User;
   
use strict;
use warnings;
use feature 'say';

our @ISA = 'System';

sub __gitPull
{
	my ($self,$timeout, $runFile) = @_;

	chdir $self->{'repository'};
	eval {
		local $SIG{ALRM} = sub { die "alarm\n" }; # NB: \n required

		alarm $timeout;
		Kalacem::fatalEc(Kalacem::EC_SOFTWARE, "[$self->{'programName'}] Unexpected error.") if system("git pull -q");

		alarm 0;
	};
	if ($@) {
		Kalacem::fatalEc(Kalacem::EC_SOFTWARE, "[$self->{'programName'}] Unexpected error.") unless $@ eq "alarm\n";   # propagate unexpected errors

		Kalacem::fatalEc(Kalacem::EC_TEMPFAIL, "[$self->{'programName'}] Timeout ($timeout seconds) expired waiting for 'git pull' to complete.");
	}

	my $rc = $self->check(0);
	open my $fc, ">", $runFile;

	close $fc;		
	say "[$self->{'programName'}] Updates available. Merge them by running 'kalacem --import'." if ($rc == Kalacem::MOD_CENTRAL);

	return Kalacem::EC_OK;
}

sub _destination
{
	my ($self, $realpath) = @_;

	return $realpath =~ s#$ENV{'HOME'}/\.#$self->{'repository'}/#r;
}

sub _init
{
	my $self = shift;

	$self->{config} = "$ENV{'HOME'}/.config/$self->{programName}.cfg";
	$self->{description} = "your home directory";
	$self->{repository} = "$ENV{'HOME'}/.local/share/$self->{programName}";
	return $self;
}

sub _inRepository
{
	my ($self, $realpath) = @_;

	if (rindex $realpath, $ENV{'HOME'}, 0) {
		$self->{error} = "$realpath is outside of home directory." ;
		return Kalacem::IR_OUTSIDE;
	}
	return $self->inRepository($realpath);
}

sub _keyToFile
{
	my ($self,$key) = @_;

	return "$ENV{'HOME'}/.$key";
}

sub cmd_update
{
	my ($self,$argv) = @_;
	my $runFile = $ENV{'XDG_RUNTIME_DIR'}."/".$self->{programName};
	my $updateRequired = 0;
	my $timeout = 3;

	$self->healthRequired(Kalacem::RS_RO);
	if (@$argv) {
		Kalacem::fatalEc(Kalacem::EC_USAGE, "Argument TIMEOUT must be an integer.") unless ($$argv[0] =~ /^\d+$/);

		$timeout = $$argv[0];
	}
	my $rc = $self->check(0);

	if ($rc == Kalacem::MOD_CENTRAL) {
		say "[$self->{'programName'}] Central modifications not yet merged locally.";
		return Kalacem::EC_FAILURE;
	}
	if ($rc == Kalacem::MOD_LOCAL) {
		say "[$self->{'programName'}] Local modifications not yet pushed to central repository.";
		return Kalacem::EC_FAILURE;
	}
	if ($rc != Kalacem::MOD_NONE) {
		say "[$self->{'programName'}] A misalignment between home directory and central repository requires manual intervention.";
		return Kalacem::EC_FAILURE;
	}
	if (! -e $runFile) {
		$updateRequired = 1;
	}
	else {
		my ($dev,$ino,$mode,$nlink,$uid,$gid, $rdev, $size, $atime, $mtime, $ctime, $blksize, $blocks) = lstat($runFile);
		$updateRequired = 1 if(time()-$mtime > $self->{'expiration'});
	}
	return $updateRequired ? $self->__gitPull($timeout, $runFile) : Kalacem::EC_OK;
}

1;
