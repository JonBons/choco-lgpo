import unittest
import requests
import zipfile
import io
import os
import hashlib
from github import Github

LGPO_URL = "https://download.microsoft.com/download/8/5/C/85C25433-A1B0-4FFA-9429-7E023E7DA8D8/LGPO.zip"
EXPECTED_FILES = [
    "LGPO.exe",
    "License.txt"
]
EXPECTED_SHA256 = "AB7159D134A0A1E7B1ED2ADA9A3CE8CE8F4DE391D14403D55438AF824247CC55"

class TestLGPODownload(unittest.TestCase):
    def test_lgpo_download_and_contents(self):
        try:
            response = requests.get(LGPO_URL, timeout=30)
            response.raise_for_status()
        except requests.RequestException as e:
            self._create_github_issue("LGPO Download URL is broken", f"The LGPO download URL is no longer accessible: {str(e)}")
            self.fail(f"Failed to download LGPO: {str(e)}")

        # Verify SHA256
        content_hash = hashlib.sha256(response.content).hexdigest()
        if content_hash.upper() != EXPECTED_SHA256:
            self._create_github_issue(
                "LGPO ZIP checksum mismatch",
                f"Expected SHA256: {EXPECTED_SHA256}\nActual SHA256: {content_hash.upper()}"
            )
            self.assertEqual(content_hash.upper(), EXPECTED_SHA256)

    def _create_github_issue(self, title, body):
        if "GITHUB_TOKEN" in os.environ:
            g = Github(os.environ["GITHUB_TOKEN"])
            repo = g.get_repo(os.environ["GITHUB_REPOSITORY"])
            repo.create_issue(
                title=title,
                body=body,
                labels=["bug", "automated-report"]
            )

if __name__ == "__main__":
    unittest.main()
