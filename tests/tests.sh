#!/bin/sh -e

BSYNC="../bsync"

DIR1=/tmp/bsyncdir1
DIR2=/tmp/bsyncdir2
SSHLOGIN=$(whoami)@positon.org
SSHDIR=/tmp/bsyncremotedir

rm -rf "$DIR1" 
rm -rf "$DIR2" 

########

# bsync with no args should fail
$BSYNC && exit

# bsync with no dir should fail
$BSYNC $DIR1 $DIR2 && exit

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
ls $DIR1/bigdir/sub/dir/bu/deepfile && exit
ls $DIR2/mydir/abc && exit

# sync with y response
echo y | $BSYNC $DIR1 $DIR2
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
echo y | $BSYNC $DIR1 $DIR2
[ -h $DIR2/bigdir/thelink ]
[ -h $DIR1/bigdir/bond ]

## ssh: no remote dir should fail
#$BSYNC $SSHLOGIN:$SSHDIR $DIR1 && exit
#
## ssh sync with dir1
#ssh $SSHLOGIN mkdir $SSHDIR
#echo $BSYNC $SSHLOGIN:$SSHDIR $DIR
#$BSYNC $SSHLOGIN:$SSHDIR $DIR
#ssh $SSHLOGIN "[ -h $SSHDIR/bigdir/thelink -a -f $SSHDIR/bigdir/sub/dir/bu/deepfile ]"



########

rm -rf "$DIR1" 
rm -rf "$DIR2" 

echo
echo "All tests are OK !!!!"
exit 0
