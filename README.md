bsync
=====

Bidirectional synchronization using rsync

It's an alternative to Unison, written in Python 3. bsync can detect and apply moved files from one side to the other. (Unison uses some copy calls to handle moved files)

I developped it to be able to synchronize my music directory from my laptop to my Raspberry Pi in an efficient way, and to sync with my girlfriend laptop too.

It uses 'rsync' for file transfers, 'find' to generate file lists, and 'ssh' for remote transfers.

Install
-------

    wget https://raw.github.com/dooblem/bsync/master/bsync
    chmod +x bsync

Be sure to have rsync installed on local and remote locations.

Usage
-----

    ./bsync DIRECTORY1 DIRECTORY2
    ./bsync DIRECTORY2 user@sshserver:DIRECTORY3
    
Example
-------

    $ ./bsync dir1 dir2
    Loading filelists...
    dir1                        dir2                   
    new                    -->                         (copy)
    subdir/a               -->  subdir/a               (sync)
                           <--  newdir/                (mkdir)
                           <--  newdir/newfile         (copy)
    Apply actions? [y/N] y
    Applying actions...
    rsync: new
    rsync: subdir/a
    rsync: newdir/newfile
    Updating filelists...
    Done!

    $ ./bsync dir1 dir2
    Loading filelists...
    Identical directories. Nothing to do.
    
Features
--------

* Moved files detection
* Remote directories using SSH
* No problem with symlinks or permissions
* Conflict detection
* No python dependency on remote locations (just GNU find and rsync)
* Exclude some subdirectories from sync (just create a `.bsync-ignore` file)
* Move your sync dirs without loosing sync memory (filelists stored in `.bsync-snap-*` files)

not yet supported :
* files owners/groups ignored

.bsync-ignore files
-------------------

You can add directories/files paths in a `.bsync-ignore` file located at the root of a sync directory.
Every path in it will be ignored when syncing with other dirs. You can also see that as a mask for the synchronization.

Say, if I have a `dir1/.bsync-ignore` file with content:
    path/to/ignoredir
    path/to/ignorefile

`dir1/path/to/ignoredir` and `dir1/path/to/ignorefile` will be ignored in the next bsync runs.
