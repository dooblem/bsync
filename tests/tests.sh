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

test_no_args() {
	echo "**test_no_args**"
	# bsync with no args should fail
	if $BSYNC; then
		return 1
	fi
}

test_dir_not_here() {
	echo "**test_dir_not_here**"
	# bsync with no dir should fail
	if $BSYNC $DIR1 $DIR2; then
		return 1
	fi
}

test_empty_dirs() {
	echo "**test_empty_dirs**"
	# bsync with empty dirs
	$BSYNC $DIR1 $DIR2
	[ "$(ls $DIR1)" = "" ]
	[ "$(ls $DIR2)" = "" ]
	find $DIR1 | grep bsync-snap
	find $DIR2 | grep bsync-snap
}

test_empty_response() {
	echo "**test_empty_response**"
	# sync with empty response
	echo | $BSYNC $DIR1 $DIR2
	if ls $DIR1/bigdir/sub/dir/bu/deepfile || ls $DIR2/mydir/abc; then
		return 1
	fi
}

test_simple_sync() {
	echo "**test_simple_sync**"
	# sync with y response
	yes | $BSYNC $DIR1 $DIR2
	ls $DIR1/bigdir/sub/dir/bu/deepfile
	ls $DIR2/mydir/abc
}

test_simple_conflict() {
	echo "**test_simple_conflict**"
	echo content1 >> $DIR1/mydir/a
	echo content22 >> $DIR2/mydir/a

	echo "2a
y" | $BSYNC $DIR1 $DIR2
	grep content2 $DIR1/mydir/a
	grep content2 $DIR2/mydir/a
}

test_non_interactive() {
	echo "**test_non_interactive**"
	echo content31 > $DIR1/mydir/d
	$BSYNC -b $DIR1 $DIR2
        grep content31 $DIR2/mydir/d
}

test_non_interactive_exit() {
	echo "**test_non_interactive exit**"
        # sync in non-interactive mode. should perform sync and exit on first conflict
	echo content34 > $DIR1/mydir/c
	echo content678 > $DIR2/mydir/c

	if $BSYNC -b $DIR1 $DIR2; then
		return 1
	fi
	grep content34 $DIR1/mydir/c
	grep content678 $DIR2/mydir/c

	rm -f $DIR1/mydir/c
	rm -f $DIR2/mydir/c
}

test_symlinks() {
	echo "**test_symlinks**"
	# some symlinks
	ln -s anytarget $DIR1/bigdir/thelink
	ln -s roiiiuyer $DIR1/otherlink
	ln -s anytarget $DIR2/bigdir/bond
	ln -s roiiiuyer $DIR2/otherlink2
	yes | $BSYNC $DIR1 $DIR2
	[ -h $DIR2/bigdir/thelink ]
	[ -h $DIR1/bigdir/bond ]
}

test_ssh_fail_noremotedir() {
	echo "**test_ssh_fail_noremotedir**"
	# ssh: should fail with no remote dir
	if $BSYNC $SSHLOGIN:$SSHDIR $DIR1; then
		return 1
	fi
}

test_ssh_sync_portarg() {
	echo "**test_ssh_sync_portarg**"
	yes | $BSYNC -p22 $SSHLOGIN:$SSHDIR $DIR1
	ssh $sshargs $SSHLOGIN "[ -h $SSHDIR/bigdir/thelink -a -f $SSHDIR/bigdir/sub/dir/bu/deepfile ]"
}

test_ssh_optionarg() {
	echo "**test_ssh_optionarg**"
	# -o option test
	touch $DIR1/mydir/otheremptyfile
	yes | $BSYNC -p22 -o "-v -p22" $SSHLOGIN:$SSHDIR $DIR1
}

test_ssh_moves() {
	echo "**test_ssh_moves**"
	# move test
	# a move in local dir: a2
	mv $DIR1/mydir/a $DIR1/a2
	# another move in remote dir: b3
	ssh $sshargs $SSHLOGIN mv $SSHDIR/mydir/b $SSHDIR/b3
	yes | $BSYNC $SSHLOGIN:$SSHDIR $DIR1
	# check that a2 and b3 are here
	[ -f $DIR1/a2 -a -f $DIR1/b3 ]
	ssh $sshargs $SSHLOGIN "[ -f $DIR1/a2 -a -f $DIR1/b3 ]"
}

test_exotic_filename_ssh() {
	echo "**test_exotic_filename_ssh**"
	touch "$DIR1/exotic:$(head -c30 /dev/urandom | tr -d '\0/')"
	yes | $BSYNC $SSHLOGIN:$SSHDIR $DIR1
	find $DIR1 | grep exotic:
	ssh $sshargs $SSHLOGIN "find $SSHDIR | grep exotic:"
}

########

test_no_args
test_dir_not_here

mkdir $DIR1
mkdir $DIR2

test_empty_dirs

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

test_empty_response
test_simple_sync

test_simple_conflict
test_non_interactive
test_non_interactive_exit

test_symlinks

test_ssh_fail_noremotedir

## ssh sync with dir1, should also work with port arg
ssh $sshargs $SSHLOGIN mkdir $SSHDIR

test_ssh_sync_portarg
test_ssh_optionarg
test_ssh_moves
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
