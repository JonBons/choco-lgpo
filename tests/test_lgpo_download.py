import unittest
import requests
import time
import hashlib
import os
from github import Github, GithubException

LGPO_URL = "https://download.microsoft.com/download/8/5/C/85C25433-A1B0-4FFA-9429-7E023E7DA8D8/LGPO.zip"
EXPECTED_SHA256 = "AB7159D134A0A1E7B1ED2ADA9A3CE8CE8F4DE391D14403D55438AF824247CC55"

class TestLGPODownload(unittest.TestCase):
    def _http_get_with_retries(self, url, attempts=3, timeout=30):
        last_exc = None
        for i in range(attempts):
            try:
                resp = requests.get(url, timeout=timeout)
                resp.raise_for_status()
                return resp
            except requests.RequestException as e:
                last_exc = e
                # Backoff before retry except last attempt
                if i < attempts - 1:
                    time.sleep(2 * (i + 1))
        raise last_exc

    def test_lgpo_download_and_contents(self):
        try:
            response = self._http_get_with_retries(LGPO_URL)
        except requests.RequestException as e:
            self._create_github_issue(
                "LGPO download URL is broken",
                f"LGPO download URL is not accessible: {str(e)}"
            )
            self.fail(f"Failed to download LGPO: {str(e)}")

        content_hash = hashlib.sha256(response.content).hexdigest().upper()
        if content_hash != EXPECTED_SHA256:
            self._create_github_issue(
                "LGPO ZIP checksum mismatch",
                f"Expected SHA256: {EXPECTED_SHA256}\nActual SHA256: {content_hash}"
            )
            self.assertEqual(content_hash, EXPECTED_SHA256)

    def _create_github_issue(self, title, body):
        token = os.environ.get("GITHUB_TOKEN")
        repo_full = os.environ.get("GITHUB_REPOSITORY")

        # Skip if we can't authenticate or we don't know which repo to post in.
        if not token or not repo_full:
            return

        # Prevent forks from trying to open issues upstream:
        # In forks, the token cannot write issues to the original repo.
        repo_owner_env = os.environ.get("GITHUB_REPOSITORY_OWNER")
        if repo_owner_env and "/" in repo_full:
            owner_of_repo = repo_full.split("/")[0]
            if owner_of_repo != repo_owner_env:
                # Running in a fork; do not attempt issue creation.
                return

        try:
            gh = Github(token)
            repo = gh.get_repo(repo_full)

            # If issues are disabled, this will raise.
            labels_to_apply = []
            desired_labels = ["bug", "automated-report"]
            existing_labels = {lbl.name for lbl in repo.get_labels()}
            for name in desired_labels:
                if name in existing_labels:
                    labels_to_apply.append(name)

            repo.create_issue(title=title, body=body, labels=labels_to_apply)
        except GithubException as e:
            # Common causes: 403 due to missing issues:write permission,
            # issues disabled, or running from fork. We swallow to keep tests deterministic.
            print(f"Skipping issue creation: {e.data if hasattr(e, 'data') else str(e)}")
        except Exception as e:
            print(f"Skipping issue creation (unexpected): {str(e)}")

if __name__ == "__main__":
    unittest.main()
