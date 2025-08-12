#!/usr/bin/env perl

# Copyright 2021 Società Distribuzione Autoricambi s.r.l., Catania.
# Copyright 2021 Lucio Tomarchio.
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

use strict;
use warnings;
use Cwd qw(getcwd realpath);
use Data::Dumper;
use File::Basename;
use Getopt::Long qw(:config no_ignore_case);
use Kalacem::System;
use Kalacem::User;
use List::Util 'sum';
use Pod::Usage;		# debian: libpod-markdown-perl perl-doc
 
# Global variables - begin
my %gOpts = (system=>0);
my %gOptEx = (check=>0, export=>0, git=>0, help=>0, import=>0, look=>0, man=>0, omit=>0, OMIT=>0, push=>0, remove=>0, update=>0, version=>0); # delete update?
my %gParameters = (expiration => 0, force => 0, programName => basename(realpath $0));
# Global variables - end
 

sub expiration
{
	my ($opt_name, $opt_value) = @_;

	$gOptEx{$opt_name} = 1;
	$gParameters{'expiration'} = $opt_value*60;
}

sub rootPrivileges
{
	die "Option --system requires root privileges.\n" if $> != 0;
	$gOpts{'system'} = 1;
}

sub main
{

	GetOptions ('help|?' => \$gOptEx{'help'},		# flag
		"check"  => \$gOptEx{"check"},			# flag
		"export"  => \$gOptEx{"export"},		# flag
		"force"  => \$gParameters{"force"},		# flag
		"git"  => \$gOptEx{"git"},			# flag
		"import"  => \$gOptEx{"import"},		# flag
		"look"  => \$gOptEx{"look"},			# flag
		"man" => \$gOptEx{"man"},			# flag
		"omit" => \$gOptEx{"omit"},			# flag
		"OMIT" => \$gOptEx{"OMIT"},			# flag
		"push" => \$gOptEx{"push"},			# flag
		"remove"  => \$gOptEx{"remove"},		# flag
		"system"  => \&rootPrivileges,			# sub
		"update=i"  => \&expiration,			# sub
		"version"  => \$gOptEx{"version"},		# flag
	) or pod2usage(2);

	my $argc=sum(@gOptEx{keys %gOptEx});
	if ($argc > 1) {
		warn "Conflicting options.\n\n";
		pod2usage(1);
	}
	elsif ($argc < 1) {
		warn "Required arguments missing.\n\n";
		pod2usage(1);
	}
	exit pod2usage(-exitval => 0, -verbose => 2) if $gOptEx{'man'};
	exit pod2usage(1) if $gOptEx{'help'};

	my $method = $gOpts{'system'} ? System->new(\%gParameters) : User->new(\%gParameters);
	# print Dumper(%gOptEx);
	foreach (keys(%gOptEx)) {
		my $command = "cmd_$_";
		exit $method->$command(\@ARGV) if ($gOptEx{$_})
	}
	die "command not found\n";
}

exit main();
__END__

=encoding utf8
 
=head1 NAME
 
Kalacem - Keep Aligned Local And CEntral Modifications
 
=head1 SYNOPSIS
 
kalacem <--check|--export|--import> [--system]

kalacem --git [--force] [--system] [REPOSITORY]

kalacem <--help|--man|--version>

kalacem <--look|--OMIT|--push|--remove> [--system] FILE...

kalacem --omit [--system] [FILE...]

kalacem --update EXPIRATION [TIMEOUT]
 
=head1 OPTIONS
 
=over 8
 
=item B<--check>
 
Check for misalignment. Detect which files were modified in local directories and in central repository.
Very often launched before B<--import> or B<--export>.
 
=item B<--export>
 
Copy modified files from local system to repository.

=item B<--git>
 
Start using B<kalacem> for home directory or systemwide. If I<REPOSITORY> is missing it returns the path of the configured one (if any). B<--force> to overwrite current configuration.
 
=item B<--help>
 
Print a brief help message and exits.
 
=item B<--import>
 
Copy updated files from repository to home directory or to F</> if launched with --system.
 
=item B<--look>
 
Check if I<FILE> is already included in the central repository. It can look for more than one file at a time.
 
=item B<--man>
 
Prints the manual page and exits.
 
=item B<--omit>
 
Don't import or export I<FILE>. If F<FILE> is omitted returns the list of currently ignored files. Accept several files at once and looks a lot like F<.gitignore>.
 
=item B<--OMIT>
 
Remove I<FILE> from ignore list.
 
=item B<--push>
 
Add single or multiple files to repository.
 
=item B<--remove>
 
Remove single or multiple files from repository. Files in original tree are untouched.

=item B<--update EXPIRATION>
 
In use by F<~/.profile> or equivalent shell init script. Try to update the repository I<EXPIRATION> minutes after the latest check. I<TIMEOUT> (in seconds, default 3) is referred to the underlying C<git pull>.
 
=item B<--version>

Prints version and exits.
 
=back

All the options can be shortened to a first letter only format (e.g., C<kalacem --check> and C<kalacem -c> perform the same operation).

=head1 DESCRIPTION
 
B<Kalacem> will help you keeping aligned your home directory or your host with a central repository.

B<Kalacem> uses two different realms for this task, the I<User> and the I<System>.
The I<User> is the default one and you can switch to the I<System> with the switch of the same name (B<--system>).

Disambiguation: on B<kalacem>'s terms, I<local> referes to the actual filesystem and I<central> to the local copy of the L<git(1)> repository.


=head1 THE SYSTEM REALM

A well known strategy to prevent the headache after a catastrophic event is to install a brand new system and restore the customized files previously backuped.
B<Kalacem> is your friend if you decide to store the divergent files in a private L<git(1)> repository, as it will help you to save, track and restore them.
The workflow with B<kalacem> is as follows:

=over 4
 
=item * Create an empty L<git(1)> repository;
 
=item * Forward it to a remote site;

=item * Declare the repository by running C<kalacem --git GITDIR> where I<GITDIR> is the directory you created at the first step;

=item * B<--push> the files you want to save. B<Kalacem> will rebuild every subdirectory paths under the GITDIR and will copy the files in their relative directories.
Then it will perform the usual L<git(1)> steps to B<add>, B<commit> and B<push> your host repository to the remote one.
 
=back

After this, if you modify (in the system root tree) any files previously I<pushed> by B<kalacem> you will be able to find them it in the list produced invoking C<kalacem --check>, no matters the current working directory.

If you want to export the local modifications to the L<git(1)> all you need to do is to type C<kalacem --export> and B<kalacem> will (L<git(1)>) add, (L<git(1)>) commit and (L<git(1)>) push everything for you.

On the other hand, if the I<central repository> (aka I<GITDIR>) brings to you some novelty, then you can B<--import> them with the command you are guessing.
It's up to you to C<git pull> your central repository if you need it.

Remember two things:

=over 4
 
=item 1.  It's security crucial that the host L<git(1)> repository should be owned by root.
 
=item 2.  If you abort a remote alignment (B<--export> or B<--push>) then you B<must> check the situation in the host repository with the ordinary L<git(1)> tools.

=back

=head1 THE USER REALM

Everytime you install a new system you find your home directory almost empty, cointaing just what was copied from F</etc/skel>.
So the shell lacks your usual aliases, L<vim(1)> doesn't show your favorite theme, the prompt sucks and so on.
A good way to recreate the "perfect" environment is to store the personal configuration files in a L<git(1)> repository.
If the repository permits anonymous download then B<kalacem> is the perfect tool to manage it. Just follow the next steps:

=over 4
 
=item * Clone somewhere the repository as you used to with ordinary L<git(1)> tools;
 
=item * Configure B<kalacem> to use this repository: C<kalacem --git /path/to/the/repository> (or simply C<kalacem --git .> if you C<cd>ed there);

=item * C<kalacem --import> to copy all the files from the central repository in their respective directories recreating the tree. Note that every file in the top level B<must not> be I<hidden>. A dot will be prefixed while copying (only for destination);

=item * Be sure that F<.bashrc> - or whatever is the shell initialization file - contains a line like C<which kalacem E<gt>/dev/null && kalacem --update 120 || echo 'This host requires kalacem'>. 
Every time you open a new shell, if last check happened more than 120 minutes ago, B<kalacem> will I<pull> from remote repository and new updates will be notified, ready to be merged into your home just typing C<kalacem --import>.
Any other kind of misalignment will be notified too and you can have a list of local and central changes typing C<kalacem --check>.
 
=back

With B<kalacem> on your side you have never more to worry to keep track of the improvements of your initialization and configuration files because a soon as you edit one all you need is C<kalacem --export> to align all the hosts you have an account on.

B<Kalacem> doesn't require write permissions on the remote repository as long as you don't need to B<--export> or B<--push> anything. Then you can safely use anonymous F<git://> protocol and customize your shell even on hosts you don't ultimately trust. It works fine as well if the remote repository to pull from is not anonymous but anyway passwordless.

=head1 FILES

=over 4

=item * F<$HOME/.config/kalacem/omissis>: Ignore file for I<User realm>.

=item * F<$HOME/.config/kalacem/remote>: Configuration file for I<User realm>.
 
=item * F<$HOME/.local/share/kalacem>: Symbolic link to local repository for I<User realm>.
 
=item * F</etc/kalacem/omissis>: Ignore file for I<System realm>.
 
=item * F</etc/kalacem/remote>: Configuration file for I<System realm>.

=item * F</etc/kalacem/repository>: Symbolic link to local repository for I<System realm>.

Both configuration files at the present cointain just the name of the writable remote repository.
Those names are autodetected when running C<kalacem --git GITDIR>. It's necessary to C<git remote add SOMETING> with read/write access before B<kalacem>'s initialization.

=back

=head1 BUGS AND LIMITATIONS

Since user git repository very often is an anonymous one, B<don't> save any very private file there, such as L<ssh(1)> keys, etc.

The I<User Realm> is aimed to the conservation of hidden files and visible files in hidden directories only. Trying to store visible files at the top level will result in an undefined behaviour.

It's unlikely it could really happen but since B<kalacem> deals with the most important files of your home directory and/or of your entire host, it has the ability to log you out forever while screwing up the whole system. This is B<experimental> software yet.


=head1 COPYRIGHT

Copyright 2021 Società Distribuzione Autoricambi s.r.l., Catania.
Copyright 2021 Lucio Tomarchio.
License  GPLv3+:  GNU GPL version 3 or later <https://gnu.org/licenses/gpl.html>.
This  is  free  software:  you  are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.

=cut
