#!/usr/bin/python3
# -*- coding: utf-8 -*-

# bsync - Bidirectional file synchronization using rsync
# Copyright (C) 2013  Marc MAURICE
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

import os, sys, shutil, subprocess, collections, time, datetime, shlex, getopt, stat

# from python3.3 tree: Lib/shlex.py (shlex.quote not in python3.2)
import re
_find_unsafe = re.compile(r'[^\w@%+=:,./-]', re.ASCII).search
def quote(s):
    """Return a shell-escaped version of the string *s*."""
    if not s:
        return "''"
    if _find_unsafe(s) is None:
        return s
    # use single quotes, and put single quotes into double quotes
    # the string $'b is then quoted as '$'"'"'b'
    return "'" + s.replace("'", "'\"'\"'") + "'"

def quotepath(path):
	return b"'" + path.replace(b"'", b"'\"'\"'") + b"'"

def tostr(o):
	if type(o) is bytes:
		return o.decode(errors='replace')
	else:
		return o

# a file record from snapshots (original file)
class OrigFile():
	def __init__(self, inode1,inode2, path,type,date,size,perms):
		self.path = path
		self.i1 = inode1
		self.i2 = inode2
		self.type = type
		self.date = date
		self.size = size
		self.perms = perms

# a file record from an actual directory
class DirFile():
	def __init__(self, inode, path, type, date, size, perms):
		self.i = inode
		self.path = path
		self.type = type
		self.date = date
		self.size = size
		self.perms = perms

class SshCon():
	def __init__(self, userhost, port, customargs):
		self.userhost = userhost
		self.sock = None
		self.port = port
		self.customargs = shlex.split(customargs)

	def getcmdlist(self):
		port = ["-p"+self.port] if self.port!=None else []
		return ["ssh"] + ["-S"+self.sock] + port + self.customargs + [self.userhost]

	def getcmdstr(self):
		return joinargs(self.getcmdlist())

def joinargs(arglist):
	cmd = ""
	for arg in arglist:
		cmd+= " "+quote(arg)+" "
	return cmd

def samefiles(f1, f2):
	# only take size in account for regular files
	if f1.type == "f" and f2.type == "f":
		return f1.date==f2.date and f1.perms==f2.perms and f1.size==f2.size
	else:
		return f1.type==f2.type and f1.date==f2.date and f1.perms==f2.perms

def printv(s):
	global verbose
	if verbose: print(s)

def printerr(s):
	print(s, file=sys.stderr)

def ssh_master_init(ssh):
	import tempfile, atexit
	tmpdir = tempfile.mkdtemp()
	ssh.sock = os.path.join(tmpdir, "bsync_%r@%h:%p")
	try:
		subprocess.check_call( ssh.getcmdlist()+["-fNM"] )
	except subprocess.CalledProcessError:
		sys.exit("Error: could not open SSH connection.")
	except FileNotFoundError:
		sys.exit("Error: ssh is not installed.")

	atexit.register(ssh_master_clean, tmpdir, ssh)

def ssh_master_clean(tmpdir, ssh):
	# send exit signal to ssh master, this will remove the socket
	printv("Cleaning SSH master...")
	with open(os.devnull, 'w') as devnull:
		ret = subprocess.call(ssh.getcmdlist()+["-Oexit"], stderr=devnull)
	if ret != 0:
	        printerr("Error in ssh master exit cmd.")
		
	try:
		os.rmdir(tmpdir) # remove tmpdir (should be empty)
	except OSError:
		time.sleep(0.5)
		try:
			os.rmdir(tmpdir)
		except:
			printerr("Could not remove tmpdir: "+tmpdir)

findformat = "%i\\0%P\\0%y\\0%T@\\0%s\\0%#m\\0"
# find test1/ -printf "%i\t%P\t%y\t%T@\t%s\t%#m\n"

def ssh_shell_init(ssh):
	return subprocess.Popen(ssh.getcmdlist()+["sh -e"], stdin=subprocess.PIPE)

def rsync_init(sshSrc,dirnameSrc, sshDst,dirnameDst):
	#rsync ssh/dir1 --> local/dir2
	#rsync local/dir1 --> ssh/dir2
	#
	#rsync ssh/dir2 --> local/dir1
	#rsync local/dir2 --> ssh/dir1
	rsyncsrc = getdirstr(sshSrc, dirnameSrc)+"/"
	rsyncdst = getdirstr(sshDst, dirnameDst)+"/"

	args = [ "-a", "--files-from=-", "--from0", "--no-implied-dirs", "--out-format=rsync: %n%L" ]
	if ssh != None:
		cmdlist = ssh.getcmdlist()
		cmdlist.remove(ssh.userhost)
		args.append("-e "+joinargs(cmdlist))

	return subprocess.Popen(["rsync"]+args+[rsyncsrc, rsyncdst], stdin=subprocess.PIPE)

def rsync_check_install(ssh):
	remote_check = ""
	if ssh != None:
		remote_check = " && "+ssh.getcmdstr()+" which rsync"

	with open(os.devnull, 'w') as devnull:
		ret = subprocess.call("which rsync"+remote_check, shell=True, stdout=devnull, stderr=devnull)
	if ret != 0:
		sys.exit("Error: please check that rsync is installed (both local and remote sides)")

# check if find supports printf option, and also remote find if ssh needed
def find_check_command(ssh):
	localfind = remotefind = None
	findhelp = "(On OSX, you can download it with brew install)"
	findargs = ["-maxdepth", "0" ,"-printf", "OK"]

	with open(os.devnull, 'w') as devnull:
		try:
			subprocess.check_call(["find"]+findargs, stdout=devnull, stderr=devnull)
			localfind = "find"
		except:
			try:
				subprocess.check_call(["gfind"]+findargs, stdout=devnull, stderr=devnull)
				localfind = "gfind"
			except:
				sys.exit("Error: local GNU find not found. "+findhelp)
	
		if ssh != None:
			if subprocess.call(ssh.getcmdlist()+["find"]+findargs, stdout=devnull, stderr=devnull) == 0:
				remotefind = "find"
			elif subprocess.call(ssh.getcmdlist()+["gfind"]+findargs, stdout=devnull, stderr=devnull) == 0:
				remotefind = "gfind"
			else:
				sys.exit("Error: remote GNU find not found. "+findhelp)
		
	return localfind, remotefind

# check if the filesystem supports permissions
def fs_check_perms(ssh, dirname):
	testtmpfile = quote( dirname+"/.bsync-permtest-"+datetime.datetime.now().strftime("%Y%m%d%H%M%S.%f") )
	# try to create a file with no permissions at all
	# if the resulting file perms is 0, the fs supports permissions (non fat...)
	testpermcmd = "umask 777; touch "+testtmpfile+"; [ \"$(stat -c%a "+testtmpfile+")\" = \"0\" ]; ret=$?; rm -f "+testtmpfile+"; exit $ret"

	with open(os.devnull, 'w') as devnull:
		if ssh == None:
			ret = subprocess.call(testpermcmd, shell=True, stdout=devnull,stderr=devnull)
		else:
			ret = subprocess.call(ssh.getcmdlist()+[testpermcmd], stdout=devnull,stderr=devnull)

	if ret==0:
		return True
	else:
		print(getdirstr(ssh,dirname)+" has no permission support (fat?). Ignoring permissions.")
		return False

# check with rsync that directories are identical (-c flag)
def rsync_check(sshSrc,dirnameSrc, sshDst,dirnameDst):
	rsyncsrc = getdirstr(sshSrc, dirnameSrc)+"/"
	rsyncdst = getdirstr(sshDst, dirnameDst)+"/"

	args = [ "-anO", "--delete", "--out-format=%n%L", "--exclude=/.bsync-snap-*" ]
	if ssh != None:
		args.append("-e "+ssh.getcmdstr())

	diff = subprocess.check_output(["rsync"]+args+[rsyncsrc, rsyncdst], universal_newlines=True).split("\n")

	diff.remove("")
	diff.remove("./")

	if len(diff) != 0:
		sys.exit("Error: rsync_check differences:\n"+str(diff))

# take a snapshot of files states from dir, using find. store it in .bsync-snap-XXXX
# snap format: inode, path, type, date...
def make_snapshot(ssh,dirname, oldsnapname, newsnapname):
	global findformat, findcmdlocal, findcmdremote

	cmd = " %s -fprintf %s '%s'" % (quote(dirname), quote(dirname+"/"+newsnapname), findformat)
	if oldsnapname!=None:
		cmd+= " && rm -f "+quote(dirname+"/"+oldsnapname)
	# remove inconsistent newsnap if error in find
	cmd+= " || ( rm -f "+quote(dirname+"/"+newsnapname)+" && false )"

	if ssh==None:
		ret = subprocess.call(findcmdlocal+cmd, shell=True)
	else:
		ret = subprocess.call(ssh.getcmdlist()+[findcmdremote+cmd])

	if ret != 0: sys.exit("Error making a snapshot.")

def make_snapshots(ssh1,dir1name, ssh2,dir2name, oldsnapname):
	newsnapname = ".bsync-snap-"+datetime.datetime.now().strftime("%Y%m%d%H%M%S.%f")
	print("Updating filelists...")
	printv("Updating snap files: "+newsnapname+"...")
	make_snapshot(ssh1,dir1name, oldsnapname,newsnapname)
	make_snapshot(ssh2,dir2name, oldsnapname,newsnapname)

# run find in a directory to dump its content
def get_find_proc(ssh, dirname):
	global findformat, findcmdlocal, findcmdremote
	if ssh==None:
		return subprocess.Popen([ findcmdlocal, dirname, "-printf", findformat ], stdout=subprocess.PIPE)
	else:
		return subprocess.Popen(ssh.getcmdlist()+[findcmdremote+" "+quote(dirname)+" -printf '"+findformat+"'" ], stdout=subprocess.PIPE)

# get a file descriptor to read the snapshot file
def get_snap_fd(ssh, dirname, snapname):
	if ssh==None:
		return open(dirname+"/"+snapname, "rb")
	else:
		return subprocess.Popen(ssh.getcmdlist()+ [ "cat "+quote(dirname+"/"+snapname) ], stdout=subprocess.PIPE).stdout

# returns all .bsync-snap-* and .bsync-ignore filenames from dir
def get_bsync_files(ssh, dirname):
	files = set()
	try:
		if ssh==None:
			for f in os.listdir(dirname):
				f = tostr(f) #avoid problems with non utf8 chars
				if f.startswith(".bsync-"):
					files.add(f)
		else:
			out = subprocess.check_output(ssh.getcmdlist()+["[ -r "+quote(dirname)+" ] && cd "+quote(dirname)+" 2>/dev/null && ( ls -1 .bsync-* 2>/dev/null || true )" ], universal_newlines=True)
			files = set( out.split("\n") )
	except (FileNotFoundError, subprocess.CalledProcessError):
		sys.exit("Error: could not open directory: "+getdirstr(ssh,dirname)+" (is it created?)")

	snaps = set()
	ignorefile = None
	for f in files:
		if f == ".bsync-ignore":
			ignorefile = f
		elif f.startswith(".bsync-snap-"):
			snaps.add(f)
			
	return snaps, ignorefile

# get ignore entries from .bsync-ignore file
def get_ignores(ignorefile, ssh,dirname):
	if ignorefile == None: return set()

	if ssh==None:
		with open(dirname+"/"+ignorefile) as fd:
			out = fd.read()
	else:
		out = subprocess.check_output(ssh.getcmdlist()+[ "cat "+quote(dirname+"/"+ignorefile) ], universal_newlines=True)

	lines = out.split("\n")

	ignores = set()
	for l in lines:
		if l != "":
			if not l.endswith("/"): l+="/"
			ignores.add(l)
	return ignores

# returns True if the path has to be ignored
# ignore root path and .bsync files
def ignorepath(path, ignoreset):
	if path == b"" or path.startswith(b".bsync-"):
		return True
	else:
		for ignore in ignoreset:
			if (path+b"/").startswith(ignore.encode()):
				return True
	return False

# http://stackoverflow.com/questions/9237246/python-how-to-read-file-with-nul-delimited-lines
# http://bugs.python.org/issue1152248
# modified to work on byte strings
def fileLineIter(inputFile,
                 inputNewline=b"\0",
                 outputNewline=None,
                 readSize=8192):
   """Like the normal file iter but you can set what string indicates newline.

   The newline string can be arbitrarily long; it need not be restricted to a
   single character. You can also set the read size and control whether or not
   the newline string is left on the end of the iterated lines.  Setting
   newline to '\0' is particularly good for use with an input file created with
   something like "os.popen('find -print0')".
   """
   if outputNewline is None: outputNewline = inputNewline
   partialLine = b''
   while True:
       charsJustRead = inputFile.read(readSize)
       if not charsJustRead: break
       partialLine += charsJustRead
       lines = partialLine.split(inputNewline)
       partialLine = lines.pop()
       for line in lines: yield line + outputNewline.rstrip(b'\0') # little mod
   if partialLine: yield partialLine.rstrip(b'\0') # little mod

def read_file_record(gen):
	global ignoreperms

	i=p=t=d=s=perms=None
	try:
		i,p,t,d,s,perms = next(gen),next(gen),next(gen),next(gen),next(gen),next(gen)
		# convert all to str except path
		i = i.decode()
		t = t.decode()
		d = d.decode()
		s = s.decode()
		perms = perms.decode()
	except StopIteration:
		if i==None and p==None and t==None and d==None and s==None and perms==None:
			return None
		else:
			sys.exit("Error: snap filelists not coherent.")

	d = d.split(".")[0]	# truncate date to seconds
	if t=="d": d=s="0"	# ignore dates/size for dirs (set to zero)
	if ignoreperms: perms = ""

	return i,p,t,d,s,perms

# load original file records from snapshots, and ignore entries
def load_orig(ssh1,dir1name, ssh2,dir2name):
	global ignoreperms

	snaps1, ignorefile1 = get_bsync_files(ssh1,dir1name)
	snaps2, ignorefile2 = get_bsync_files(ssh2,dir2name)

	# ignore perms if one fs doesnt support perms (vfat...)
	# check is done after checking if directories are present
	if not ignoreperms:
		ignoreperms = not (fs_check_perms(ssh1,dir1name) and fs_check_perms(ssh2,dir2name))

	ignores1 = get_ignores(ignorefile1, ssh1,dir1name)
	ignores2 = get_ignores(ignorefile2, ssh2,dir2name)
	ignores = ignores1 | ignores2

	common_snaps = snaps1.intersection(snaps2)
	orig = collections.OrderedDict()
	if len(common_snaps) == 0:
		print("Old filelist not found. Starting with empty history.")
		return (None, orig, ignores) #empty snap and orig

	snapname = max(common_snaps) #the most recent snapshot

	printv("Loading "+snapname+"...")

	fd1 = get_snap_fd(ssh1, dir1name, snapname)
	fd2 = get_snap_fd(ssh2, dir2name, snapname)
	gen1 = fileLineIter(fd1)
	gen2 = fileLineIter(fd2)

	# iterate on gen1 to fill orig
	# first fill with 1st snap, then with 2nd snap, because the order can be different (in find output)
	record = read_file_record(gen1)
	if record==None: sys.exit("Error reading files from dir1 filelist") #should be at least one record (dir root)
	while record != None:
		inode,path,type,date,size,perms = record

		if not ignorepath(path, ignores):
			orig[path] = OrigFile(inode,None, path,type,date,size,perms)
		
		record = read_file_record(gen1)

	# iterate on gen2, fill inodes for dir2 and check for consistency
	record = read_file_record(gen2)
	if record==None: sys.exit("Error reading files from dir2 filelist")
	while record != None:
		inode,path,type,date,size,perms = record

		if not ignorepath(path, ignores):
			#path not in orig: can happen if using ignore, then removing ignore, path will be considered as new
			if path in orig:
				origfile = orig[path]
				if origfile.type != type or origfile.date != date or origfile.size != size or origfile.perms != perms:
					sys.exit("Error: difference in snaps for path: "+tostr(path)) 

				origfile.i2 = inode #set the second inode
		
		record = read_file_record(gen2)

	fd1.close()
	fd2.close()

	return snapname, orig, ignores

def getdirstr(ssh,dirname):
	return dirname if ssh==None else ssh.userhost+":"+dirname

# load actual directory content
def load_dir(ssh, dirname, ignores):
	dir = collections.OrderedDict()

	proc = get_find_proc(ssh, dirname)
	fd = proc.stdout
	gen = fileLineIter(fd)

	record = read_file_record(gen)
	while record != None:
		inode,path,type,date,size,perms = record

		if not ignorepath(path, ignores):
			dir[path] = DirFile(inode, path, type, date, size, perms)
		
		record = read_file_record(gen)

	fd.close()
	proc.wait()
	if proc.returncode != 0:
		sys.exit("Find Error in "+getdirstr(ssh,dirname))
	
	return dir

def getdatestr(f):
	return time.strftime("%Y-%m-%d %H:%M:%S", time.localtime( int(f.date.split(".")[0]) ))

def getfilemode(type, perms):
	if type=="f": type="-"
	try:
		# filemode() only exists in pyton3.3
		return type + stat.filemode(int(perms, 8))[1:]
	except AttributeError:
		o2str = { '7':'rwx', '6':'rw-', '5':'r-x', '4':'r--', '0':'---' }
		return type + o2str[perms[-3]] + o2str[perms[-2]] + o2str[perms[-1]]

def show_conflict(f1, f2, path):
	if f1 == None:
		p1 = "*deleted*"
		p2 = getfilemode(f2.type, f2.perms)+" "+f2.size+"B ("+getdatestr(f2)+")"
	elif f2 == None:
		p1 = getfilemode(f1.type, f1.perms)+" "+f1.size+"B ("+getdatestr(f1)+")"
		p2 = "*deleted*"
	else:
		p1=p2=""
		if f1.type != f2.type or f1.perms != f2.perms:
			p1+= getfilemode(f1.type, f1.perms)+" "
			p2+= getfilemode(f2.type, f2.perms)+" "
		
		# size and date are meaningless for dirs. conflicts will not be on them
		# don't display them if one side is a directory
		if f1.size != f2.size and f1.type!="d" and f2.type!="d":
			p1+= f1.size+"B "
			p2+= f2.size+"B "

		if f1.date != f2.date and f1.type!="d" and f2.type!="d":
			p1+= "("+getdatestr(f1)+")"
			p2+= "("+getdatestr(f2)+")"

	print("CONFLICT detected on: "+tostr(path))
	print_action("", "LEFT DIR CHANGE", "   ", "RIGHT DIR CHANGE")
	print_action("", p1, "   ", p2)
	print()

def print_line():
	global console_width
	if console_width == 0: console_width = 80
	print("~" * console_width)

# ask the user about conflicting changes
# conflict can be on type, date, size, perms
def ask_conflict(f1, f2, path, tokeep):
	if tokeep=="1a" or tokeep=="2a":
		return tokeep

	resp = None
	while True:
		print_line()
		show_conflict(f1, f2, path)

		if resp!=None:
			print("	1	Keep left version")
			print("	2	Keep right version")
			print("	1a	Keep left version for all")
			print("	2a	Keep right version for all")
			print("  Please note: you will be able to confirm the actions later.\n")

		resp = myinput("Which one do I keep? [1/2/1a/2a/Quit/Help] ")

		if resp == "1" or resp == "2" or resp == "1a" or resp == "2a":
			return resp
		elif resp == "q" or resp == "Q" or resp == "Quit":
			sys.exit(0)

#### file actions
def remove(shproc, path):
	if shproc == None:
		os.remove(path)
	else:
		shproc.stdin.write( b"rm " + quotepath(path) + b"\n" )
		shproc.stdin.flush()

def removedir(shproc, path):
	if shproc == None:
		try:
			os.rmdir(path)
		except OSError as e:
			#pass
			print("Warning: "+str(e)) # can happen: dir removed in 1, file dir/f added in 2
	else:
		shproc.stdin.write( b"rmdir " + quotepath(path) + b" || true\n" )
		shproc.stdin.flush()

def mkdir(shproc, path, perms):
	if shproc == None:
		if perms=="":
			os.mkdir(path)
		else:
			os.mkdir(path, int(perms, 8) )
	else:
		if perms=="":
			shproc.stdin.write( b"mkdir " + quotepath(path) + b"\n" )
		else:
			shproc.stdin.write( b"mkdir -m" + perms.encode() + b" " + quotepath(path) + b"\n" )
		shproc.stdin.flush()

def move(shproc, src, dst, perms):
	if shproc == None:
		os.rename(src, dst)
		if perms!="":
			os.chmod(dst, int(perms, 8) )
	else:
		shproc.stdin.write( b"mv " + quotepath(src) + b" " + quotepath(dst) + b"\n" )
		if perms!="":
			shproc.stdin.write( b"chmod " + perms.encode() + b" " + quotepath(dst) + b"\n" )
		shproc.stdin.flush()

# just write a path in rsync process stdin
def rsync(rsyncproc, path):
	rsyncproc.stdin.write(path+b"\0")
	rsyncproc.stdin.flush()

def print_action(action, path1, arrow, path2):
	global console_width
	w = 0
	if console_width != 0:
		w = (console_width -1-3-2 -1-11) // 2

	action = "("+action+")" if action!="" else ""

	print( tostr(path1).ljust(w) +" "+arrow+"  "+ tostr(path2).ljust(w) +" "+action )

def get_dir_summary(mkdir,moves,rm,rmdirs,copy,sync):
	actions = []
	if len(mkdir)>0:  actions.append("mkdir:"+str(len(mkdir)))
	if len(moves)>0:  actions.append("mv:"+str(len(moves)))
	if len(rm)>0:     actions.append("rm:"+str(len(rm)))
	if len(rmdirs)>0: actions.append("rmdir"+str(len(rmdirs)))
	if len(copy)>0:   actions.append("cp:"+str(len(copy)))
	if len(sync)>0:   actions.append("sync:"+str(len(sync)))
	return " ".join(actions)

def print_files(fo, f1, f2):
	print("%s: i:%s d:%s | i:%s d:%s (orig)" % (fo.path, fo.i1, fo.date, fo.i2, fo.date))
	f1str = f1str = "i:"+f1.i+" d:"+str(f1.date) if f1!=None else ""
	f2str = f2str = "i:"+f2.i+" d:"+str(f2.date) if f2!=None else ""
	print("%s: %s | %s" % (fo.path, f1str, f2str))
def print_files12(path, f1, f2):
	f1str = f1str = "i:"+f1.i+" d:"+str(f1.date) if f1!=None else ""
	f2str = f2str = "i:"+f2.i+" d:"+str(f2.date) if f2!=None else ""
	print("%s: %s | %s" % (path, f1str, f2str))

# print actions before asking user validation
def print_actions(dirnum, mkdirs,moves,rm,rmdirs, copy,sync):

	# mkdirss must be done before
	for f in mkdirs:
		if dirnum==2:
			print_action("mkdir", tostr(f.path)+"/", "-->", "")
		else:
			print_action("mkdir", "", "<--", tostr(f.path)+"/")

	# moves
	for fromfile, targetfile in moves:
		if dirnum==2:
			print_action("move", targetfile.path, "-->", "from:"+tostr(fromfile.path))
		else:
			print_action("move", "from:"+tostr(fromfile.path), "<--", targetfile.path)

	# removes, after the check moves step
	for f in rm.values():
		if dirnum==2:
			print_action("rm", "", "-->", f.path)
		else:
			print_action("rm", f.path, "<--", "")

	# rmdirs must be done after
	for path in rmdirs:
		if dirnum==2:
			print_action("rmdir", "", "-->", path)
		else:
			print_action("rmdir", path, "<--", "")

	##### actions involving a transfer
	# finish with copy and sync
	for path in copy:
		if dirnum==2:
			print_action("copy", path, "-->", "")
		else:
			print_action("copy", "", "<--", path)
	for path in sync:
		if dirnum==2:
			print_action("sync", path, "-->", path)
		else:
			print_action("sync", path, "<--", path)
# end print_actions

# apply small actions: mkdirs, moves, rm, rmdirs
# quick actions, via local python or remote ssh shell
def apply_small_actions(ssh,dirname, mkdirs,moves,rm,rmdirs):
	if mkdirs==[] and moves==[] and len(rm)==0 and rmdirs==[]:
		return

	shproc = None
	# if we need a ssh shell
	if ssh != None:
		shproc = ssh_shell_init(ssh)

	# mkdirss must be done before
	os.umask(0000) #disable umask to allow for any mkdirs
	for f in mkdirs:
		mkdir(shproc, dirname.encode()+b"/"+f.path, f.perms)

	# moves
	for fromfile, targetfile in moves:
		perms = "" if fromfile.perms == targetfile.perms else targetfile.perms
		move(shproc, dirname.encode()+b"/"+fromfile.path, dirname.encode()+b"/"+targetfile.path, perms)

	# removes, after the check moves step
	for f in rm.values():
		remove(shproc, dirname.encode()+b"/"+f.path)

	# rmdirs must be done after
	for path in rmdirs:
		removedir(shproc, dirname.encode()+b"/"+path)

	if shproc != None:
		shproc.stdin.close()
		shproc.wait() # wait shell process to exit
		if shproc.returncode != 0:
			sys.exit("Error in shell process.")

##### actions involving an rsync transfer
def apply_rsync_actions(sshSrc,dirnameSrc, sshDst,dirnameDst, pathlist):
	if len(pathlist) == 0:
		return

	rsyncproc = rsync_init(sshSrc,dirnameSrc, sshDst,dirnameDst)

	# finish with copies and sync
	for path in pathlist:
		rsync(rsyncproc, path)

	# clean rsyncproc
	rsyncproc.stdin.close()
	rsyncproc.wait()
	if rsyncproc.returncode != 0:
		sys.exit("Error in rsync process.")

def check_moves(copy, rm):
	# check if we can move instead of rm+copy
	# return resulting copy/rm actions + moves
	moves = []
	copyreal = []
	for fsrc in copy: # f1 in copy12
		# we must copy f1 to dir2
		# to use a move: search for f1 inode
		# f1.i == fo.i1 <> fo.i2 == f2.i
		fcandidate = rm.get(fsrc.i, None) # check if we can use a move

		# check date to be sure that no change on file.
		if fcandidate != None and fcandidate.type == fsrc.type and fcandidate.date == fsrc.date and fcandidate.size == fsrc.size:
			moves.append( (fcandidate, fsrc) )
			rm.pop(fsrc.i)
		else:	
			copyreal.append(fsrc.path)

	return copyreal, rm, moves

# handle Ctrl+C in prompts
def myinput(prompt):
	try:
		return input(prompt)
	except KeyboardInterrupt:
		sys.exit(" ")

def usage():
	usage = "Usage: bsync [options] DIR1 DIR2\n\n"
	usage+= "	DIR can be user@sshserver:DIR\n"
	usage+= "	-v		Verbose\n"
	usage+= "	-i		Ignore permissions\n"
	usage+= "	-p PORT		Port for SSH\n"
	usage+= "	-o SSHARGS	Custom options for SSH\n"
	printerr(usage)

#####################################################

#### process commandline args
try:
	opts, args = getopt.gnu_getopt(sys.argv[1:], "vcip:o:")
except getopt.GetoptError as err:
	printerr(err)
	usage()
	sys.exit(2)

verbose = check = ignoreperms = False
sshport = None
sshargs = ""
for o, a in opts:
	if o == "-v":
		verbose = True
	elif o == "-i":
		ignoreperms = True
	elif o == "-c":
		check = True
	elif o == "-p":
		sshport = a
	elif o == "-o":
		sshargs = a
	else:
		assert False, "unhandled option"

if len(args) != 2:
	usage()
	sys.exit(2)

dir1name = args[0]
dir2name = args[1]

# get ssh connection
ssh = ssh1 = ssh2 = None
if ':' in dir1name:
	sshuserhost, dir1name = dir1name.split(':', 1)
	ssh = ssh1 = SshCon(sshuserhost, sshport, sshargs)
if ':' in dir2name:
	sshuserhost, dir2name = dir2name.split(':', 1)
	ssh = ssh2 = SshCon(sshuserhost, sshport, sshargs)
if ssh1!=None and ssh2!=None:
	sys.exit("Error: only one remote directory supported.")

if ssh != None:
	ssh_master_init(ssh)

# check rsync and find installs
rsync_check_install(ssh)
findcmdlocal, findcmdremote = find_check_command(ssh)

# add trailing slashes (to avoid problems with symlinked dirs)
dir1name = os.path.join(dir1name, '')
dir2name = os.path.join(dir2name, '')

# try to get console width, for displaying actions, if running interactive
try:
	with open(os.devnull, 'w') as devnull:
		height, width = subprocess.check_output(['stty', 'size'], universal_newlines=True, stderr=devnull).split()
	console_width = int(width)
except:
	console_width = 0

print("Loading filelists...")

printv("Loading original filelist from snap files...")
snapname, origlist, ignores = load_orig(ssh1,dir1name, ssh2,dir2name)

printv("Loading dir1 filelist...")
dir1 = load_dir(ssh1, dir1name, ignores)
printv("Loading dir2 filelist...")
dir2 = load_dir(ssh2, dir2name, ignores)

dir1tmp = dir1.copy()
dir2tmp = dir2.copy()
# just show conflicts
conflicts = []
for path, fo in origlist.items():
	f1 = dir1tmp[path] if path in dir1tmp else None
	f2 = dir2tmp[path] if path in dir2tmp else None

	if f1 == None and f2 == None:
		pass
	elif f1 != None and f2 != None and samefiles(f1,f2):
		pass
	elif f2 != None and samefiles(f2,fo):
		# no f2 change --> f1 change only
		pass
	elif f1 != None and samefiles(f1,fo):
		# no f1 change --> f2 change only
		pass
	else:
		# f1 change and f2 change --> confict
		conflicts.append( (f1, f2, path) )

	dir1tmp.pop(path, None)
	dir2tmp.pop(path, None)

for path, f1 in dir1tmp.items():
	f2 = dir2tmp[path] if path in dir2tmp else None

	if f2 != None and samefiles(f2,f1):
		# f1 and f2 added but same files --> nothing to do
		pass
	elif f2 == None:
		# adding in d2
		pass
	else:
		# f2!=None and f2.date != f1.date --> conflict
		conflicts.append( (f1, f2, path) )

	dir2tmp.pop(path, None)

if len(conflicts) > 0:
	print()
	for f1, f2, path in conflicts:
		show_conflict(f1, f2, path)

printv("Analysing original paths...")
mkdir1 = []
mkdir2 = []
rmdirs1 = []
rmdirs2 = []
rm1 = collections.OrderedDict()
rm2 = collections.OrderedDict()
copy12 = []
copy21 = []
sync12 = []
sync21 = []
tokeep = None
# process all original paths (from snapshot)
for path, fo in origlist.items():
	# f1==None f2==None				deleted both sides
	# f1==None f2=!None f2.d==fo.d			f1 chg only
	# f1==None f2=!None f2.d!=fo.d			conflict
	# f1!=None f2==None f1.d==fo.d			f2 chg only
	# f1!=None f2==None f1.d!=fo.d			conflict
	# f1!=None f2!=None f1.d==fo.d f2.d==fo.d	no change
	# f1!=None f2!=None f1.d==fo.d f2.d!=fo.d	f2 chg only
	# f1!=None f2!=None f1.d!=fo.d f2.d==fo.d	f1 chg only
	# f1!=None f2!=None f1.d!=fo.d f2.d!=fo.d	conflict

	f1 = dir1[path] if path in dir1 else None
	f2 = dir2[path] if path in dir2 else None

	if f1 == None and f2 == None:
		# deleted both sides --> nothing to do
		pass
	elif f1 != None and f2 != None and samefiles(f1,f2):
		# same file contents --> nothing to do
		pass
	elif f2 != None and samefiles(f2,fo):
		# no f2 change --> f1 change only
		if f1 == None:
			# f1 deleted --> delete f2
			if f2.type == "d": # f2 isdir
				rmdirs2.append(path)
			else:
				rm2[fo.i1] = f2
		else:
			# f1 != None and f1 != fo.date --> f1 mod --> mod f2
			sync12.append(path)
	elif f1 != None and samefiles(f1,fo):
		# no f1 change --> f2 change only
		if f2 == None:
			if f1.type == "d": #f1 isdir
				rmdirs1.append(path)
			else:
				rm1[fo.i2] = f1
		else:
			sync21.append(path)
	else:
		# f1 change and f2 change --> confict
		# f1 != None and f2 != None --> f1.date != f2.date (!= fo.date)
		# f1 == None and f2 != None
		# f1 != None and f2 == None

		tokeep = ask_conflict(f1, f2, path, tokeep);
		if tokeep[0] == "1": #1 or 1a
			if f1 == None:
				if f2.type == "d": # f2 isdir
					rmdirs2.append(path)
				else:
					rm2[fo.i1] = f2
			else:
				if f2 == None:
					if f1.type == "d":
						mkdir2.append(f1)
					else:
						copy12.append(f1)
				else:
					sync12.append(path)
		else: # tokeep == 2
			if f2 == None:
				if f1.type == "d": # f1 isdir
					rmdirs1.append(path)
				else:
					rm1[fo.i2] = f1
			else:
				if f1 == None:
					if f2.type == "d":
						mkdir1.append(f2)
					else:
						copy21.append(f2)
				else:
					sync21.append(path)
	#ifend

	dir1.pop(path, None)
	dir2.pop(path, None)
#forend

printv("Analysing remaining new paths in dir1...")
# process new paths in dir1
for path, f1 in dir1.items():
	f2 = dir2[path] if path in dir2 else None

	if f2 != None and samefiles(f2,f1):
		# f1 and f2 added but same files --> nothing to do
		pass
	elif f2 == None:
		# adding in d2
		if f1.type == "d":
			mkdir2.append(f1)
		else:
			copy12.append(f1)
	else:
		# f2!=None and f2.date != f1.date --> conflict
		tokeep = ask_conflict(f1, f2, path, tokeep);
		if tokeep[0] == "1":
			sync12.append(path)
		else: # tokeep == 2
			sync21.append(path)

	dir2.pop(path, None)

# remaining in dir2: new paths not in orig nor in dir1 --> no conflict
printv("Analysing remaining new paths in dir2...")
# process remaining new paths in dir2
for path, f2 in dir2.items():
	if f2.type == "d":
		mkdir1.append(f2)
	else:
		copy21.append(f2)

# moves detection
copy12, rm2, moves2 = check_moves(copy12, rm2)
copy21, rm1, moves1 = check_moves(copy21, rm1)

rmdirs1.sort(reverse=True) # TODO someth cleaner than sort?
rmdirs2.sort(reverse=True) # TODO someth cleaner than sort?

# ACTIONS in dir2 -->
# ACTIONS in dir1 <--

# if no action to do
if len(mkdir1)==0 and len(moves1)==0 and len(rm1)==0 and len(rmdirs1)==0 and len(copy21)==0 and len(sync21)==0 and \
   len(mkdir2)==0 and len(moves2)==0 and len(rm2)==0 and len(rmdirs2)==0 and len(copy12)==0 and len(sync12)==0:
	if check: rsync_check(ssh1,dir1name, ssh2,dir2name)
	print("Identical directories. Nothing to do.")
	if snapname == None:
		make_snapshots(ssh1,dir1name, ssh2,dir2name, snapname)
	sys.exit()

if len(conflicts) > 0: print_line()
print()
print_action("ACTION", "(LEFT DIR CONTENT)", "   ", "(RIGHT DIR CONTENT)")
print()
print_actions(2, mkdir2,moves2,rm2,rmdirs2, copy12,sync12)
print_actions(1, mkdir1,moves1,rm1,rmdirs1, copy21,sync21)

print()
print("Todo in "+args[0]+": "+get_dir_summary(mkdir1,moves1,rm1,rmdirs1, copy21,sync21))
print("Todo in "+args[1]+": "+get_dir_summary(mkdir2,moves2,rm2,rmdirs2, copy12,sync12))

resp = "none"
while resp != "y" and resp != "n":
	resp = myinput("Apply actions? [y/N] ").lower()
	if resp == "": resp = "n"
print()
if resp == "n":
	print("Leaving files in place.")
	sys.exit()

print("Applying actions...")

printv("Applying actions in dir2...")
apply_small_actions(ssh2,dir2name, mkdir2,moves2,rm2,rmdirs2)
apply_rsync_actions(ssh1,dir1name,ssh2,dir2name, copy12 + sync12)

printv("Applying actions in dir1...")
apply_small_actions(ssh1,dir1name, mkdir1,moves1,rm1,rmdirs1)
apply_rsync_actions(ssh2,dir2name,ssh1,dir1name, copy21 + sync21)

if check: rsync_check(ssh1,dir1name, ssh2,dir2name)

make_snapshots(ssh1,dir1name, ssh2,dir2name, snapname)

print("Done!")
