bsync
=====

Bidirectional synchronization using rsync

bsync is a bidirectional synchronization tool, an alternative to Unison.

It uses 'rsync' for file transfers, 'find' to generate file lists, and 'ssh' for remote transfers.

Install
-------

    wget https://raw.github.com/dooblem/bsync/master/bsync
    chmod +x bsync
    
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
