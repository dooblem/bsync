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
    
