"""Exercise the tag guard against real Git refs without touching the app repo."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / 'validate-release.sh'


class ReleaseTagTests(unittest.TestCase):
    def test_main_and_rejected_refs(self):
        with tempfile.TemporaryDirectory(prefix='linkrouter-tag-test-') as directory:
            def git(*args):
                subprocess.run(['git', *args], cwd=directory, check=True,
                               capture_output=True)

            git('init', '-b', 'main')
            git('config', 'user.email', 'test@example.invalid')
            git('config', 'user.name', 'Release test')
            file = Path(directory, 'file')
            file.write_text('main')
            git('add', 'file')
            git('commit', '-m', 'main')
            git('remote', 'add', 'origin', directory)
            git('tag', '-a', 'v1.2.3', '-m', 'Release')
            env_file = Path(directory, 'env')

            def validate(ref):
                return subprocess.run(
                    ['bash', str(SCRIPT)], cwd=directory, capture_output=True,
                    env=dict(os.environ, GITHUB_REF=ref, GITHUB_ENV=str(env_file)))

            self.assertEqual(validate('refs/tags/v1.2.3').returncode, 0)
            self.assertEqual(env_file.read_text(), 'VERSION=1.2.3\n')
            for ref in ['refs/heads/main', 'refs/tags/v1.2',
                        'refs/tags/v01.2.3', 'refs/tags/v1.2.3-beta']:
                with self.subTest(ref=ref):
                    self.assertNotEqual(validate(ref).returncode, 0)
            git('switch', '-c', 'unmerged')
            file.write_text('branch')
            git('commit', '-am', 'unmerged')
            git('tag', 'v2.0.0')
            self.assertNotEqual(validate('refs/tags/v2.0.0').returncode, 0)
            self.assertNotEqual(validate('refs/tags/v1.2.3').returncode, 0)


if __name__ == '__main__':
    unittest.main()
