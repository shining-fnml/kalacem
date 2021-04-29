# Copyright 2021 Lucio Tomarchio
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

package System;

use strict;
use warnings;
use feature 'say';
use Cwd qw(getcwd realpath);
use Data::Dumper;
use Digest::MD5 qw(md5_hex);
use Fcntl ':mode';
use File::Basename;
use File::Copy 'cp';
use File::Find;
use File::Path qw(make_path);
use IO::Prompter;
use Kalacem::Kalacem qw(fatal);
use List::MoreUtils qw(any);

use constant {
	SL_NONE   => -1,
	SL_BROKEN =>  0,
	SL_OK     =>  1
};

our @gExportable;
our @gImportable;
our %gFile;

# Convention:
# _method: required in both System and User classes.
# __method: local/private.
# cmd_method: interface for command line argument.
# method: invoked by both parent and children classes.

sub new
{
	my ($class,$parameters) = @_;
	my $self = bless {
		config => "/etc/$parameters->{'programName'}/$parameters->{'programName'}.cfg",
		description => "this system",
		error => 'Unknown error',
		expiration => $parameters->{'expiration'},
		force => $parameters->{'force'},
		programName => $parameters->{'programName'},
		remote => "",
		repostatus => Kalacem::RS_UNDEFINED,
		repository => "/etc/$parameters->{'programName'}/repository",
	}, $class;

	$self->_init();
	$self->__start();
	return $self;
}

sub __configWrite
{
	my ($self,$lRepository) = @_;
	my $remote = "";

	chdir $lRepository;
	my @remotes = $self->__gitRemote();
	return unless ($remote eq "");

	unless (scalar @remotes) {
		unlink ($self->{'config'}) if -e $self->{'config'};
		Kalacem::fatalEc(Kalacem::EC_UNAVAILABLE, "No write enabled repositories found.");
	}

	if (scalar @remotes == 1) {
		$remote = $remotes[0];
	}
	else {
		push @remotes, "<abort>";

		my $selection = prompt "Select a remote for git", -menu => \@remotes, '>', -stdio;

		$remote = $selection;
		Kalacem::fatalEc(Kalacem::EC_CONFIG, "Aborted.") if ($selection eq "<abort>");
	}
	$self->__parentDirForFile($self->{'config'}, 1);

	unless (open my $handle, ">", $self->{'config'}) {
		warn "Cannot write to $self->{'config'}.\n";
	}
	else {
		print $handle $remote;
		close($handle);
	}
}

sub __gitAddCommitPush
{
	my $self = shift;

	Kalacem::fatalEc(Kalacem::EC_NOINPUT, "Nothing to be exported.") unless @gExportable;

	my $cmdline = "git add ".(join (" ", @gExportable)." >/dev/null 2>&1");
	Kalacem::fatalEc(Kalacem::EC_SOFTWARE, "Unexpected error running '$cmdline' in directory $self->{'repository'}.") if system ($cmdline);

	return $self->__gitCommitPush(scalar @gExportable);
}

sub __gitCommitPush
{
	my ($self, $count) = @_;

	Kalacem::fatalEc(Kalacem::EC_IOERR, "Cannot read from $self->{'config'}.") unless open (my $handle, "<", $self->{'config'});

	my $repository = <$handle>;
	chomp $repository;
	close($handle);

	unless ($count) {
		my $selection = prompt "Ready to push changes to $repository. Proceed?", -Yes=>1, -stdio;
		Kalacem::fatalEc(Kalacem::EC_FAILURE, "Aborted.") if ($selection ne "Y");
	}
	else {
		my $plural = $count > 1 ? "s" : "";
		my $selection = prompt "Ready to commit and push $count file$plural to remote '$repository'. Proceed?", -Yes=>1, -stdio;
		Kalacem::fatalEc(Kalacem::EC_FAILURE, "Aborted.") if ($selection ne "Y");

		Kalacem::fatalEc(Kalacem::EC_SOFTWARE, "Unexpected error running 'git commit' in directory $self->{'repository'}.") if system ("git commit -q");
	}
	return system ("git push -q $repository");
}

sub __gitRemote
{
	my $self = shift;
	my $cwd = getcwd();
	my @match;
	my @remotes;

	chdir $self->{'repository'};
	my @grv=`git remote -v`;

	foreach (@grv) {
		push @remotes, $match[0] if (@match = $_ =~ /(\w+)\s+ssh:\/\/(\w+@)?((?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)|(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)+([A-Za-z]|[A-Za-z][A-Za-z0-9\-]*[A-Za-z0-9]))(\/\w+)+\.git\s+\(push\)/m);
	}
	chdir $cwd;
	return @remotes;
}

sub __importExport
{
	my ($self,$direction) = @_;
	my @details = (
		{ iterable => \@gImportable, label => "imported", mod_expected => Kalacem::MOD_CENTRAL },
		{ iterable => \@gExportable, label => "exported", mod_expected => Kalacem::MOD_LOCAL   });

	my $rc = $self->check(0);

	Kalacem::fatalEc Kalacem::EC_FAILURE, "Run '$self->{programName} --check' and then fix this situation manually." if ($rc == Kalacem::MOD_BOTH);

	Kalacem::fatalEc Kalacem::EC_OK, "There's nothing to be $details[$direction]->{label}." if ($rc != $details[$direction]->{mod_expected});

	foreach (@{$details[$direction]->{iterable}}) {
		my $source = $direction ?  $self->_keyToFile($_) : "$self->{'repository'}/$_";
		my $destination = $direction ? "$self->{'repository'}/$_" : $self->_keyToFile($_);

		Kalacem::fatalEc(Kalacem::EC_CANTCREAT, "An error occured creating directory ".dirname($destination)." while copying from $source to $destination") unless $self->__parentDirForFile($destination);

		Kalacem::fatalEc(Kalacem::EC_IOERR, "Error copying from $source to $destination") if (! cp($source, $destination));
	}
	return Kalacem::EC_OK;
}

sub __isGit
{
	my ($self,$lRepository) = @_;
	my $cwd = getcwd();

	Kalacem::fatalEc(Kalacem::EC_NOINPUT, "No such directory '$lRepository'") if ! -d $lRepository;

	chdir $lRepository;

	my $rc = system("git rev-parse --is-inside-work-tree > /dev/null 2>&1") ? 0 : 1;
	chdir $cwd;
	return $rc;
}

sub __parentDirForFile
{
	my ($self, $filename, $fatal) = @_;
	my $pathDir = dirname ($filename);

	return 1 if (-d $pathDir);

	make_path($pathDir, {error => \my $err});

	return 1 unless ($err && @$err);

	$self->{'error'} = "Error creating directory $pathDir";
	Kalacem::fatalEc (Kalacem::EC_CANTCREAT, $self->{'error'}) if $fatal;

	return 0;
}

sub __pushRemoveCommon
{
	my ($self, $argv, $label, $condition, $good) = @_;
	my @errors;

	Kalacem::fatal("$label what?") if (!scalar @$argv);

	foreach (@$argv) {
		my $realpath = realpath $_;

		if ($self->_inRepository($realpath) == $condition) {
			push @$good, $realpath;
		}
		else {
			push @errors, $self->{'error'};
		}
	}
	if (scalar @errors) {
		print STDERR "$_\n" foreach (@errors);
		return 0;
	}
	return 1;
}

sub __start
{
	my $self = shift;

	if (! -e $self->{'repository'}) {
		$self->{'error'} = "$self->{programName} is not in use in $self->{description}.";
		$self->{'repostatus'} = Kalacem::RS_MISSING;
		say "Kalacem::RS_MISSING";
	}
	elsif (! -l $self->{'repository'}) {
		$self->{'repostatus'} = Kalacem::RS_BROKEN;
		$self->{'error'} = "Installation looks broken because $self->{'repository'} is not a symlink.";
		say "Kalacem::RS_BROKEN";
	}
	elsif (!stat $self->{'repository'}) {
		$self->{'repostatus'} = Kalacem::RS_BADLINK;
		$self->{'error'} = "Installation looks out of date because $self->{'repository'} is pointing to a broken path.";
	}
	elsif (!$self->__isGit($self->{'repository'})) {
		$self->{'error'} = $self->{'repository'}." is not a git repository.";
		$self->{'repostatus'} = Kalacem::RS_NOGIT;
	}
	else {
		my @remotes = $self->__gitRemote();

		if (!@remotes) {
			$self->{'error'} = "Central repository is read-only.";
			$self->{'repostatus'} = Kalacem::RS_RO;
		}
		elsif (! -r $self->{'config'}) {
			$self->{'error'} = "Central repository is not set read-write yet.";
			$self->{'repostatus'} = Kalacem::RS_NOWRITE;
		}
		elsif (!open my $handle, "<", $self->{'config'}) {
			$self->{'error'} = "Cannot read from $self->{'config'}.";
			$self->{'repostatus'} = Kalacem::RS_BADCONF;
		}
		else {
			$self->{'remote'} = <$handle>;
			chomp $self->{'remote'};
			close($handle);
			if (any{$_ eq $self->{'remote'}} @remotes) {
				$self->{'repostatus'} = Kalacem::RS_OK;
			}
			else {
				$self->{'error'} = "Configured remote '$self->{remote}' is not available.";
				$self->{'repostatus'} = Kalacem::RS_BADREMOTE;
			}
		}
	}
}

sub _destination
{
	my ($self, $source) = @_;

	return $self->{repository}.$source;
}

sub _init
{
	return shift;
}

sub _inRepository
{
	my ($self,$realpath) = @_;

	return $self->inRepository($realpath);
}

sub _keyToFile
{
	my ($self,$key) = @_;

	return "/".$key;
}

sub check
{
	my ($self,$verbose) = @_;
	my @errors;

	chdir $self->{'repository'};
	File::Find::find({wanted => \&wanted}, '.');

	for my $key (keys %gFile) {
		my $file = $self->_keyToFile($key);
		my @stats = lstat $file;

		if (! scalar @stats) {
			warn "missing $file\n" if $verbose;
			push @gImportable, $key;
		}
		elsif (!S_ISREG($stats[2]) && !S_ISLNK($stats[2])) {
			push @errors, "$file is not a regular file nor a symlink";
		}
		elsif ( md5File($file, $file) ne $gFile{$key}{md5} ) {
			if ($stats[9] < $gFile{$key}{mtime}) {
				print "Central modification of $file\n" if $verbose;
				push @gImportable, $key;
			}
			else {
				print "Local modification of $file\n" if $verbose;
				push @gExportable, $key;
			}
		}
	}

	my $centralMod = scalar @gImportable;
	my $localMod = scalar @gExportable;
	if (scalar @errors) {
		warn "Errors detected:";
		for my $idx (0..$#errors) {
			warn "\t$errors[$idx]\n";
		}
		return Kalacem::MOD_ERROR;
	}
	if (! $localMod && ! $centralMod) {
		say "$self->{'description'} is aligned" if $verbose;
		return Kalacem::MOD_NONE;
	}
	elsif ($localMod && $centralMod) {
		warn "Local and central modifications at the same time.\n";
		return Kalacem::MOD_BOTH;
	}
	elsif ($localMod) {
		say "$localMod local modifications" if ($verbose and $localMod > 1);
		return Kalacem::MOD_LOCAL;
	}
	say "$centralMod central modifications" if ($verbose and $centralMod > 1);
	return Kalacem::MOD_CENTRAL;
}

sub cmd_check
{
	my $self = shift;

	$self->healthRequired(Kalacem::RS_RO);

	my $rc = $self->check(1);

	return Kalacem::EC_FAILURE if $rc == Kalacem::MOD_BOTH;
	return Kalacem::EC_DATAERR if $rc == Kalacem::MOD_ERROR;
	return Kalacem::EC_OK;
}

sub cmd_export
{
	my $self = shift;

	$self->healthRequired(Kalacem::RS_OK);

	my $rc = $self->__importExport(1);
	return $rc != Kalacem::EC_OK ? $rc : $self->__gitAddCommitPush();
}

sub cmd_git
{
	my ($self,$argv) = @_;

	$self->healthRequired(Kalacem::RS_MISSING);
	my $pathRoot;

	if (scalar @$argv) {
		$pathRoot = realpath($$argv[0]);
		Kalacem::fatalEc(Kalacem::EC_PROTOCOL, "$pathRoot is not a git repository") unless $self->__isGit($pathRoot);
	}
	elsif ($self->{'repostatus'} <= Kalacem::RS_RO) {
		print realpath($self->{'repository'});
		print " (ro)" if ($self->{'repostatus'} != Kalacem::RS_OK);
		print "\n";
		return Kalacem::EC_OK;
	}
	elsif ($self->{'repostatus'} > Kalacem::RS_RO) {
		print STDERR "$self->{'error'}\n";
		return Kalacem::EC_FAILURE;
	}
	Kalacem::fatalEc(Kalacem::EC_IOERR, "$self->{'repository'} is not symlink. Fix it manually") if ($self->{'repostatus'} == Kalacem::RS_BROKEN);

	if ($self->{'repostatus'} <= Kalacem::RS_BADLINK) {
		if ($self->{'force'} || $self->{'repostatus'} == Kalacem::RS_BADLINK) {
			unlink $self->{'repository'};
		}
		else {
			Kalacem::fatal "$self->{programName} is already configured for $self->{'description'} and is pointing to $self->{'repository'}. Use --force to change it.";
		}
	}
	$self->__parentDirForFile($self->{'repository'}, 1);
	Kalacem::fatalEc (Kalacem::EC_CANTCREAT, "Error creating symlink ".$self->{'repository'}."->$pathRoot") if ! symlink $pathRoot, $self->{'repository'};
	$self->__configWrite($pathRoot);
	return Kalacem::EC_OK;
}

sub cmd_import
{
	my $self = shift;

	$self->healthRequired(Kalacem::RS_RO);
	return $self->__importExport(0);
}

sub cmd_look
{
	my ($self,$argv) = @_;

	$self->healthRequired(Kalacem::RS_RO);
	foreach (@$argv) {
		$self->_inRepository(realpath $_);

		print "$self->{'error'}\n";
	}
}

sub cmd_push
{
	my ($self,$argv) = @_;
	my @pushing;

	$self->healthRequired(Kalacem::RS_OK);
	exit Kalacem::EC_DATAERR unless $self->__pushRemoveCommon($argv, "Push", Kalacem::IR_NO, \@pushing);

	foreach my $source (@pushing) {
		my $destination = $self->_destination($source);

		$self->__parentDirForFile($destination, 1);
		Kalacem::fatalEc(Kalacem::EC_IOERR, "Error pushing from $source to $destination") if (! cp($source, $destination));
		push @gExportable, $destination =~ s#$self->{'repository'}/##r;
	}
	return $self->__gitAddCommitPush();
}

sub cmd_remove
{
	my ($self,$argv) = @_;
	my @removing;

	$self->healthRequired(Kalacem::RS_OK);
	exit Kalacem::EC_DATAERR unless $self->__pushRemoveCommon($argv, "Remove", Kalacem::IR_YES, \@removing);

	my @destinations = map { $self->_destination($_)} @removing;
	my $cmdline = "git rm -q ".join(" ", @destinations);
	Kalacem::fatalEc(Kalacem::EC_SOFTWARE, "Unexpected error running '$cmdline' in directory $self->{'repository'}.") if system ($cmdline);

	return $self->__gitCommitPush(0);
}

sub cmd_update
{
	my $self = shift;

	print STDERR "--update is not allowed together with --system\n";
	return Kalacem::EC_USAGE;
}

sub cmd_version
{
	my $self = shift;

	print "$self->{'programName'} 1.0.1\n";
	return Kalacem::EC_OK;
}

sub healthRequired
{
	my ($self,$level) = @_;

	return if ($self->{'repostatus'} <= $level);

	Kalacem::fatalEc($self->{'repostatus'}, $self->{'error'});
}

sub inRepository
{
	my ($self,$realpath) = @_;

	if (-e $self->_destination($realpath)) {
		$self->{'error'} = "$realpath is under control.";
		return Kalacem::IR_YES;
	}
	$self->{'error'} = "$realpath not monitored.";
	return Kalacem::IR_NO;
}


### Out of class subroutines

sub md5File
{
	my ($inFile, $fullPath) = @_;
	my $rc = 0;

	if (! open my $handle, "<", $inFile) {
		warn "Cannot read from $fullPath.\n";
	}
	else {
		$rc = md5_hex(<$handle>);
		close($handle);
	}
	return $rc;
}

sub wanted
{
	my ($dev,$ino,$mode,$nlink,$uid,$gid, $rdev, $size, $atime, $mtime, $ctime, $blksize, $blocks);

	return if ! (( ($dev,$ino,$mode,$nlink,$uid,$gid, $rdev, $size, $atime, $mtime, $ctime, $blksize, $blocks) = lstat($_)) && !($File::Find::name =~ /^.*\/\.git.*\z/s) && ( -l _ || -f _));

	my $dirItemPath = substr($File::Find::name, 2);
	if (my $checksum = md5File ($_, $dirItemPath)) {
		$gFile{$dirItemPath} = { md5 => $checksum, mtime => $mtime, size => $size };
	}
}

1;
