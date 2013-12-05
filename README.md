bsync
=====

Bsync is a bidirectional file synchronization tool, using rsync for transfers. __Moved files__ are also synchronized in a smart way.

It uses __rsync__ for file transfers, __find__ to generate filelist snapshots, and __ssh__ for remote transfers.

bsync is an alternative to Unison, written in __Python 3__. A big strength of bsync: it can detect and apply moved files from one side to the other (Unison uses some copy calls to handle moved files).

I developped it to be able to synchronize my music directory from my laptop to my Raspberry Pi in an efficient way, and to sync with my girlfriend laptop too.

Bsync is released under GPLv3. Feel free to report any bugs/wishes in [GitHub issues](https://github.com/dooblem/bsync/issues).


Install
-------

    wget https://raw.github.com/dooblem/bsync/master/bsync
    chmod +x bsync

For remote syncing: don't forget to install rsync.

Usage
-----

Fairly simple:

    ./bsync DIRECTORY1 DIRECTORY2
    ./bsync ALICE_DIR  bob@sshserver:BOB_DIR
   
bsync can also be used to sync with a master directory:

    # Alice makes local changes
    ./bsync ALICE_DIR MASTER_DIR
    ./bsync BOB_DIR   MASTER_DIR
    # Bob gets Alice changes, sending his changes to master in the same time
    
Features
--------

* Moved files detection (using inodes numbers)
* Remote directories using SSH
* No problem with symlinks or permissions
* Conflict detection
* Python not needed on remote side (just GNU find and rsync)
* Exclude some subdirectories from sync (just create a `.bsync-ignore` file)
* Move your sync dirs without loosing sync memory (filelists stored inside directories in `.bsync-snap-*` files)
* Auto disable permissions on fat filesystems

Limitations:
* files ownership ignored (would matter if syncing from root user, but sufficient for regular users)
* no subdir conflict detection (a bit like in git where only files matter, no conflict is detected if dir1/dir/
  removed and dir2/dir/file created the other side)

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
    
.bsync-ignore files
-------------------

You can add directories/files paths in a `.bsync-ignore` file located at the root of a sync directory.
Every path in it will be ignored when syncing with other dirs. You can also see that as a mask for the synchronization.

Say, if I have a `dir1/.bsync-ignore` file with content:

    path/to/ignoredir
    path/to/ignorefile

`dir1/path/to/ignoredir` (+content) and `dir1/path/to/ignorefile` will be ignored in the next bsync runs.
