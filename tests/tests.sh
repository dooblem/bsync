#!/bin/sh -ex

export BSYNC="./bsync"

export DIR1=/tmp/bsyncdir1
export DIR2=/tmp/bsyncdir2
export SSHLOGIN=$(whoami)@localhost
export SSHDIR=/tmp/bsyncremotetestdir

rm -rf "$DIR1" 
rm -rf "$DIR2" 
export sshargs=" -S/tmp/bsynctest_%r@%h:%p "
ssh $sshargs -fNM $SSHLOGIN # open master cxion
ssh $sshargs $SSHLOGIN "rm -rf $SSHDIR"

########

test_exotic_filename_ssh() {
	touch "$DIR1/exotic:$(head -c30 /dev/urandom | tr -d '\0/')"
	yes | $BSYNC $SSHLOGIN:$SSHDIR $DIR1
	find $DIR1 | grep exotic:
	ssh $sshargs $SSHLOGIN "find $SSHDIR | grep exotic:"
}

########

# bsync with no args should fail
$BSYNC && false

# bsync with no dir should fail
$BSYNC $DIR1 $DIR2 && false

mkdir $DIR1
mkdir $DIR2

# bsync with empty dirs
$BSYNC $DIR1 $DIR2
[ "$(ls $DIR1)" = "" ]
[ "$(ls $DIR2)" = "" ]
find $DIR1 | grep bsync-snap
find $DIR2 | grep bsync-snap

touch $DIR1/touchfile
mkdir $DIR1/mydir
touch $DIR1/mydir/a
touch $DIR1/mydir/b
touch $DIR1/mydir/abc
mkdir $DIR1/mydir2

touch $DIR2/myfile
mkdir $DIR2/bigdir
mkdir -p $DIR2/bigdir/sub/dir/bu/
echo cccc > $DIR2/bigdir/sub/dir/bu/deepfile

# sync with empty response
echo | $BSYNC $DIR1 $DIR2
ls $DIR1/bigdir/sub/dir/bu/deepfile && false
ls $DIR2/mydir/abc && false

# sync with y response
yes | $BSYNC $DIR1 $DIR2
ls $DIR1/bigdir/sub/dir/bu/deepfile
ls $DIR2/mydir/abc

echo content1 >> $DIR1/mydir/a
echo content22 >> $DIR2/mydir/a

# a conflict
echo "2a
y" | $BSYNC $DIR1 $DIR2
grep content2 $DIR1/mydir/a
grep content2 $DIR2/mydir/a

# some symlinks
ln -s anytarget $DIR1/bigdir/thelink
ln -s roiiiuyer $DIR1/otherlink
ln -s anytarget $DIR2/bigdir/bond
ln -s roiiiuyer $DIR2/otherlink2
yes | $BSYNC $DIR1 $DIR2
[ -h $DIR2/bigdir/thelink ]
[ -h $DIR1/bigdir/bond ]


# ssh: should fail with no remote dir
$BSYNC $SSHLOGIN:$SSHDIR $DIR1 && false

## ssh sync with dir1, should also work with port arg
ssh $sshargs $SSHLOGIN mkdir $SSHDIR
yes | $BSYNC -p22 $SSHLOGIN:$SSHDIR $DIR1
ssh $sshargs $SSHLOGIN "[ -h $SSHDIR/bigdir/thelink -a -f $SSHDIR/bigdir/sub/dir/bu/deepfile ]"

# -o option test
touch $DIR1/mydir/otheremptyfile
yes | $BSYNC -p22 -o "-v -p22" $SSHLOGIN:$SSHDIR $DIR1

# move test
# a move in local dir: a2
mv $DIR1/mydir/a $DIR1/a2
# another move in remote dir: b3
ssh $sshargs $SSHLOGIN mv $SSHDIR/mydir/b $SSHDIR/b3
yes | $BSYNC $SSHLOGIN:$SSHDIR $DIR1
# check that a2 and b3 are here
[ -f $DIR1/a2 -a -f $DIR1/b3 ]
ssh $sshargs $SSHLOGIN "[ -f $DIR1/a2 -a -f $DIR1/b3 ]"

test_exotic_filename_ssh

########

rm -rf "$DIR1" 
rm -rf "$DIR2" 
ssh $sshargs $SSHLOGIN "rm -rf $SSHDIR"
ssh $sshargs $SSHLOGIN -Oexit

echo
echo "
All tests are OK !!!!
All tests are OK !!!!
All tests are OK !!!!
All tests are OK !!!!
All tests are OK !!!!
"

exit 0
