# NAME

Kalacem - Keep Aligned Local And CEntral Modifications

# SYNOPSIS

kalacem <--check|--export|--import> \[--system\]

kalacem --git \[--force\] \[--system\] \[REPOSITORY\]

kalacem <--help|--man|--version>

kalacem <--look|--OMIT|--push|--remove> \[--system\] FILE...

kalacem --omit \[--system\] \[FILE...\]

kalacem --update EXPIRATION \[TIMEOUT\]

# OPTIONS

- **--check**

    Check for misalignment. Detect which files were modified in local directories and in central repository.
    Very often launched before **--import** or **--export**.

- **--export**

    Copy modified files from local system to repository.

- **--git**

    Start using **kalacem** for home directory or systemwide. If _REPOSITORY_ is missing it returns the path of the configured one (if any). **--force** to overwrite current configuration.

- **--help**

    Print a brief help message and exits.

- **--import**

    Copy updated files from repository to home directory or to `/` if launched with --system.

- **--look**

    Check if _FILE_ is already included in the central repository. It can look for more than one file at a time.

- **--man**

    Prints the manual page and exits.

- **--omit**

    Don't import or export _FILE_. If `FILE` is omitted returns the list of currently ignored files. Accept several files at once and looks a lot like `.gitignore`.

- **--OMIT**

    Remove _FILE_ from ignore list.

- **--push**

    Add single or multiple files to repository.

- **--remove**

    Remove single or multiple files from repository. Files in original tree are untouched.

- **--update EXPIRATION**

    In use by `~/.profile` or equivalent shell init script. Try to update the repository _EXPIRATION_ minutes after the latest check. _TIMEOUT_ (in seconds, default 3) is referred to the underlying `git pull`.

- **--version**

    Prints version and exits.

All the options can be shortened to a first letter only format (e.g., `kalacem --check` and `kalacem -c` perform the same operation).

# DESCRIPTION

**Kalacem** will help you keeping aligned your home directory or your host with a central repository.

**Kalacem** uses two different realms for this task, the _User_ and the _System_.
The _User_ is the default one and you can switch to the _System_ with the switch of the same name (**--system**).

Disambiguation: on **kalacem**'s terms, _local_ referes to the actual filesystem and _central_ to the local copy of the [git(1)](http://man.he.net/man1/git) repository.

# THE SYSTEM REALM

A well known strategy to prevent the headache after a catastrophic event is to install a brand new system and restore the customized files previously backuped.
**Kalacem** is your friend if you decide to store the divergent files in a private [git(1)](http://man.he.net/man1/git) repository, as it will help you to save, track and restore them.
The workflow with **kalacem** is as follows:

- Create an empty [git(1)](http://man.he.net/man1/git) repository;
- Forward it to a remote site;
- Declare the repository by running `kalacem --git GITDIR` where _GITDIR_ is the directory you created at the first step;
- **--push** the files you want to save. **Kalacem** will rebuild every subdirectory paths under the GITDIR and will copy the files in their relative directories.
Then it will perform the usual [git(1)](http://man.he.net/man1/git) steps to **add**, **commit** and **push** your host repository to the remote one.

After this, if you modify (in the system root tree) any files previously _pushed_ by **kalacem** you will be able to find them it in the list produced invoking `kalacem --check`, no matters the current working directory.

If you want to export the local modifications to the [git(1)](http://man.he.net/man1/git) all you need to do is to type `kalacem --export` and **kalacem** will ([git(1)](http://man.he.net/man1/git)) add, ([git(1)](http://man.he.net/man1/git)) commit and ([git(1)](http://man.he.net/man1/git)) push everything for you.

On the other hand, if the _central repository_ (aka _GITDIR_) brings to you some novelty, then you can **--import** them with the command you are guessing.
It's up to you to `git pull` your central repository if you need it.

Remember two things:

- 1.  It's security crucial that the host [git(1)](http://man.he.net/man1/git) repository should be owned by root.
- 2.  If you abort a remote alignment (**--export** or **--push**) then you **must** check the situation in the host repository with the ordinary [git(1)](http://man.he.net/man1/git) tools.

# THE USER REALM

Everytime you install a new system you find your home directory almost empty, cointaing just what was copied from `/etc/skel`.
So the shell lacks your usual aliases, [vim(1)](http://man.he.net/man1/vim) doesn't show your favorite theme, the prompt sucks and so on.
A good way to recreate the "perfect" environment is to store the personal configuration files in a [git(1)](http://man.he.net/man1/git) repository.
If the repository permits anonymous download then **kalacem** is the perfect tool to manage it. Just follow the next steps:

- Clone somewhere the repository as you used to with ordinary [git(1)](http://man.he.net/man1/git) tools;
- Configure **kalacem** to use this repository: `kalacem --git /path/to/the/repository` (or simply `kalacem --git .` if you `cd`ed there);
- `kalacem --import` to copy all the files from the central repository in their respective directories recreating the tree. Note that every file in the top level **must not** be _hidden_. A dot will be prefixed while copying (only for destination);
- Be sure that `.bashrc` - or whatever is the shell initialization file - contains a line like `which kalacem >/dev/null && kalacem --update 120 || echo 'This host requires kalacem'`. 
Every time you open a new shell, if last check happened more than 120 minutes ago, **kalacem** will _pull_ from remote repository and new updates will be notified, ready to be merged into your home just typing `kalacem --import`.
Any other kind of misalignment will be notified too and you can have a list of local and central changes typing `kalacem --check`.

With **kalacem** on your side you have never more to worry to keep track of the improvements of your initialization and configuration files because a soon as you edit one all you need is `kalacem --export` to align all the hosts you have an account on.

**Kalacem** doesn't require write permissions on the remote repository as long as you don't need to **--export** or **--push** anything. Then you can safely use anonymous `git://` protocol and customize your shell even on hosts you don't ultimately trust. It works fine as well if the remote repository to pull from is not anonymous but anyway passwordless.

# FILES

- `$HOME/.local/share/kalacem`: Symbolic link to local repository for _User realm_.
- `$HOME/.config/kalacem.cfg`: Configuration file for _User realm_.
- `/etc/kalacem/repository`: Symbolic link to local repository for _System realm_.
- `/etc/kalacem/kalacem.cfg`: Configuration file for _System realm_.

    Both configuration files at the present cointain just the name of the writable remote repository.
    Those names are autodetected when running `kalacem --git GITDIR`. It's necessary to `git remote add SOMETING` with read/write access before **kalacem**'s initialization.

# BUGS AND LIMITATIONS

Since user git repository very often is an anonymous one, **don't** save any very private file there, such as [ssh(1)](http://man.he.net/man1/ssh) keys, etc.

The _User Realm_ is aimed to the conservation of hidden files and visible files in hidden directories only. Trying to store visible files at the top level will result in an undefined behaviour.

It's unlikely it could really happen but since **kalacem** deals with the most important files of your home directory and/or of your entire host, it has the ability to log you out forever while screwing up the whole system. This is **experimental** software yet.

# COPYRIGHT

Copyright 2021 Società Distribuzione Autoricambi s.r.l., Catania.
Copyright 2021 Lucio Tomarchio.
License  GPLv3+:  GNU GPL version 3 or later &lt;https://gnu.org/licenses/gpl.html>.
This  is  free  software:  you  are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.
