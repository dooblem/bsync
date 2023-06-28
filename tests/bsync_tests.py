import unittest, tempfile, os, subprocess, shutil
import inspect

dir1 = "dir1"
dir2 = "dir2"

def unittest_verbosity():
	"""Return the verbosity setting of the currently running unittest
	   program, or 0 if none is running.
	   (https://stackoverflow.com/a/32883243/1259360)
	"""
	frame = inspect.currentframe()
	while frame:
		self = frame.f_locals.get('self')
		if isinstance(self, unittest.TestProgram):
			return self.verbosity
		frame = frame.f_back
	return 0

class TestBase(unittest.TestCase):

	def setUp(self):
		self._verbosity = unittest_verbosity()
		self._tempdir = tempfile.mkdtemp()
		self.dir1 = os.path.join(self._tempdir, dir1)
		self.dir2 = os.path.join(self._tempdir, dir2)
		os.mkdir(self.dir1)
		os.mkdir(self.dir2)
		self.counter = 0

	def tearDown(self):
		shutil.rmtree(self._tempdir)
		pass

	def bsync(self, args):
		verbArg = []
		if self._verbosity >= 2:
			print('Executing:\n  bsync %s "%s" "%s"' % (' '.join(args), self.dir1, self.dir2))
			verbArg = ["-v"]
		with subprocess.Popen(["bsync"]+verbArg+args+[self.dir1, self.dir2], shell=True, stdout=subprocess.PIPE) as proc:
			fd = proc.stdout
			output = fd.read()
			fd.close()
			proc.wait()
			if self._verbosity >= 2:
				print("Output from bsync execution:")
				print("vvvvvvvvvvvvvvvvvvvvvvvvvvvv")
				print(output.decode('ascii'))
				print("^^^^^^^^^^^^^^^^^^^^^^^^^^^^")
			self.assertEqual(proc.returncode, 0, "bsync failed with code %d" % proc.returncode)
		return output

	def _val(self, num):
		return "o" * num

	def updfile(self, dir, name):
		if type(name) is list:
			for n in name:
				with open(os.path.join(self._tempdir, dir, n), "w") as f:
					f.write(self._val(self.counter))
					self.counter += 1
		else:
			with open(os.path.join(self._tempdir, dir, name), "w") as f:
				f.write(self._val(self.counter))
				self.counter += 1

	def delfile(self, dir, name):
		os.remove(os.path.join(self._tempdir, dir, name))

	def assertExists(self, dir, name, msg=None):
		if type(name) is list:
			for n in name:
				self.assertTrue(os.path.exists(os.path.join(self._tempdir, dir, n)), msg)
		else:
			self.assertTrue(os.path.exists(os.path.join(self._tempdir, dir, name)), msg)

	def assertNotExists(self, dir, name, msg=None):
		if type(name) is list:
			for n in name:
				self.assertFalse(os.path.exists(os.path.join(self._tempdir, dir, n)), msg)
		else:
			self.assertFalse(os.path.exists(os.path.join(self._tempdir, dir, name)), msg)

	def assertFileContains(self, dir, name, value, msg=None):
		self.assertExists(dir, name, msg)
		with open(os.path.join(self._tempdir, dir, name), "r") as f:
			rvalue = f.read()
			self.assertEqual(rvalue, self._val(value))

class TestSync(TestBase):

	def test_1_to_2(self):
		self.updfile(dir1, ["a", "b"])
		self.bsync(["-b"])
		self.assertExists(dir2, ["a", "b"])
		self.assertFileContains(dir2, "a", 0)
		self.assertFileContains(dir2, "b", 1)

	def test_2_to_1(self):
		self.updfile(dir2, ["a", "b"])
		self.bsync(["-b"])
		self.assertExists(dir1, ["a", "b"])
		self.assertFileContains(dir1, "a", 0)
		self.assertFileContains(dir1, "b", 1)

	def test_upd(self):
		self.test_1_to_2()
		self.updfile(dir1, "a")
		self.updfile(dir2, "b")
		self.bsync(["-b"])
		self.assertFileContains(dir1, "a", 2)
		self.assertFileContains(dir2, "a", 2)
		self.assertFileContains(dir1, "b", 3)
		self.assertFileContains(dir2, "b", 3)

	def test_del(self):
		self.test_1_to_2()
		self.delfile(dir1, "a")
		self.delfile(dir2, "b")
		self.bsync(["-b"])
		self.assertNotExists(dir1, ["a", "b"])
		self.assertNotExists(dir2, ["a", "b"])

	def test_conflict(self):
		self.test_1_to_2()
		self.updfile(dir1, "a")
		self.updfile(dir2, "a")
		self.updfile(dir1, "b")
		self.delfile(dir2, "b")
		self.updfile(dir1, "c")
		self.bsync(["-b"])
		self.bsync(["-b"])
		self.assertFileContains(dir1, "a", 2)
		self.assertFileContains(dir2, "a", 3)
		self.assertFileContains(dir1, "b", 4)
		self.assertNotExists(dir2, "b")


class TestMirror(TestBase):

	def test_1_to_2(self):
		self.updfile(dir1, ["a", "b"])
		self.bsync(["-bm", "mirror"])
		self.assertExists(dir2, ["a", "b"])
		self.assertFileContains(dir2, "a", 0)
		self.assertFileContains(dir2, "b", 1)

	def test_2_to_1(self):
		self.updfile(dir2, ["a", "b"])
		self.bsync(["-bm", "mirror"])
		self.assertNotExists(dir1, ["a", "b"])
		self.assertExists(dir2, ["a", "b"])

	def test_upd(self):
		self.test_1_to_2()
		self.updfile(dir1, "a")
		self.updfile(dir2, "b")
		self.bsync(["-bm", "mirror"])
		self.assertFileContains(dir1, "a", 2)
		self.assertFileContains(dir2, "a", 2)
		self.assertFileContains(dir1, "b", 1)
		self.assertFileContains(dir2, "b", 3)

	def test_del(self):
		self.test_1_to_2()
		self.delfile(dir1, "a")
		self.delfile(dir2, "b")
		self.bsync(["-bm", "mirror"])
		self.assertNotExists(dir1, "a")
		self.assertFileContains(dir1, "b", 1)
		self.assertNotExists(dir2, ["a", "b"])

	def test_conflict(self):
		self.test_1_to_2()
		self.updfile(dir1, "a")
		self.updfile(dir2, "a")
		self.updfile(dir1, "b")
		self.delfile(dir2, "b")
		self.updfile(dir1, "c")
		self.bsync(["-bm", "mirror"])
		self.bsync(["-bm", "mirror"])
		self.assertFileContains(dir1, "a", 2)
		self.assertFileContains(dir2, "a", 3)
		self.assertFileContains(dir1, "b", 4)
		self.assertNotExists(dir2, "b")


class TestBackup(TestBase):

	def test_1_to_2(self):
		self.updfile(dir1, ["a", "b"])
		self.bsync(["-bm", "backup"])
		self.assertExists(dir2, ["a", "b"])
		self.assertFileContains(dir2, "a", 0)
		self.assertFileContains(dir2, "b", 1)

	def test_2_to_1(self):
		self.updfile(dir2, ["a", "b"])
		self.bsync(["-bm", "backup"])
		self.assertNotExists(dir1, ["a", "b"])
		self.assertExists(dir2, ["a", "b"])

	def test_upd(self):
		self.test_1_to_2()
		self.updfile(dir1, "a")
		self.updfile(dir2, "b")
		self.bsync(["-bm", "backup"])
		self.assertFileContains(dir1, "a", 2)
		self.assertFileContains(dir2, "a", 2)
		self.assertFileContains(dir1, "b", 1)
		self.assertFileContains(dir2, "b", 3)

	def test_del(self):
		self.test_1_to_2()
		self.delfile(dir1, "a")
		self.delfile(dir2, "b")
		self.bsync(["-bm", "backup"])
		self.assertNotExists(dir1, "a")
		self.assertFileContains(dir2, "a", 0)
		self.assertFileContains(dir1, "b", 1)
		self.assertNotExists(dir2, "b")

	def test_conflict(self):
		self.test_1_to_2()
		self.updfile(dir1, "a")
		self.updfile(dir2, "a")
		self.updfile(dir1, "b")
		self.delfile(dir2, "b")
		self.updfile(dir1, "c")
		self.bsync(["-bm", "backup"])
		self.bsync(["-bm", "backup"])
		self.assertFileContains(dir1, "a", 2)
		self.assertFileContains(dir2, "a", 3)
		self.assertFileContains(dir1, "b", 4)
		self.assertNotExists(dir2, "b")


class TestMixed(TestBase):

	def _1_to_2(self):
		self.updfile(dir1, ["a", "b"])
		self.bsync(["-b"])
		self.assertExists(dir2, ["a", "b"])
		self.assertFileContains(dir2, "a", 0)
		self.assertFileContains(dir2, "b", 1)

	def test_sync_after_backup(self):
		self._1_to_2()
		self.delfile(dir1, "a")
		self.updfile(dir2, "b")
		self.updfile(dir1, "c")
		self.bsync(["-bm", "backup"])
		self.bsync(["-b"])
		self.assertNotExists(dir1, "a")
		self.assertNotExists(dir2, "a")
		self.assertFileContains(dir1, "b", 2)
		self.assertFileContains(dir2, "b", 2)

	def test_mirror_after_backup(self):
		self._1_to_2()
		self.delfile(dir1, "a")
		self.updfile(dir2, "b")
		self.updfile(dir1, "c")
		self.bsync(["-bm", "backup"])
		self.bsync(["-bm", "mirror"])
		self.assertNotExists(dir1, "a")
		self.assertNotExists(dir2, "a")
		self.assertFileContains(dir1, "b", 1)
		self.assertFileContains(dir2, "b", 2)

if __name__ == '__main__':
    unittest.main(verbosity=1.5)
