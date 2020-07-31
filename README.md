bsync
=====

Bsync is a bidirectional file synchronization tool, using rsync for transfers. __Moved files__ are also synchronized in a smart way.

It uses [rsync](http://rsync.samba.org) for file transfers, [GNU find](http://www.gnu.org/software/findutils/) to generate filelist snapshots, and [ssh](http://www.openssh.com/) for remote transfers.

bsync is an alternative to Unison, written in [Python 3](http://www.python.org/). A big strength of bsync: it can detect and apply moved files from one side to the other (Unison uses some copy calls to handle moved files).

I developped it to be able to synchronize my music directory from my laptop to my [Raspberry Pi](http://www.raspberrypi.org/) in an efficient way, and to sync with my girlfriend laptop too.

Bsync is released under GPL. Feel free to report any bugs/wishes in [GitHub issues](https://github.com/dooblem/bsync/issues).


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
    
bsync help and options:

```
Usage: bsync [options] DIR1 DIR2

        DIR can be user@sshserver:DIR
        -v              Verbose
        -i              Ignore permissions
        -b              Batch mode (skip conflicts)
        -c              Check that directories are identical
        -m MODE         sync|backup|mirror (defult sync)
                                backup - copy new and modified from DIR1 to DIR2
                                mirror - backup + missing in DIR1 remove from DIR2
                                sync   - bidirectional mirror
        -p PORT         Port for SSH
        -o SSHARGS      Custom options for SSH
```
    
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
* MacOSX support (requirement: GNU find installed)

Limitations:
* files ownership ignored (would matter if syncing from root user, but sufficient for regular users)
* no subdir conflict detection (a bit like in git where only files matter, no conflict is detected if dir1/dir/
  removed and dir2/dir/file created the other side)
* No Windows support
* Not tested under: OpenBSD, FreeBSD (any feedback appreciated)

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
    
Conflict handling
-----------------

Bsync prompts the user for conflicts.

A sample run with a conflict: file deleted one side and updated the other side.

    $ bsync dir1/ dir2/
    Loading filelists...

    Conflicting changes on: testfile
    *deleted*                           <?>   -rw-r--r-- 7B (2014-01-30 18:47:40) (conflict)
    Which one do I keep [1/2/?] ?
    	1	Keep left version
    	2	Keep right version
    	1a	Keep left version for all
    	2a	Keep right version for all
    Which one do I keep [1/2/?] 2
    dir1/                                    dir2/                               
                                        <--  testfile                            (copy)
    Apply actions? [y/N] y
    Applying actions...
    rsync: testfile
    Updating filelists...
    Done!
    
.bsync-ignore files
-------------------

You can add directories/files paths in a `.bsync-ignore` file located at the root of a sync directory.
Every path in it will be ignored when syncing with other dirs. You can also see that as a mask for the synchronization.

Say, if I have a `dir1/.bsync-ignore` file with content:

    path/to/ignoredir
    path/to/ignorefile

`dir1/path/to/ignoredir` (+content) and `dir1/path/to/ignorefile` will be ignored in the next bsync runs.

The ignore file has to be very simple. No comments, just path prefixes.

### See also

[My blog](http://positon.org)
