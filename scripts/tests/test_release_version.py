"""Version changes and retry validation fail closed for native releases."""

import json
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from release_version import (
    format_tag,
    inspect_release_api_response,
    inspect_release_list_response,
    parse_version,
    release_from_change,
)


class ReleaseVersionTests(unittest.TestCase):
    def _valid_release(self):
        return {
            "tag_name": "v0.1.1",
            "draft": False,
            "prerelease": False,
            "published_at": "2026-10-09T03:08:49Z",
            "assets": [
                {
                    "name": name,
                    "state": "uploaded",
                    "size": 123,
                    "digest": "sha256:" + "a" * 64,
                }
                for name in (
                    "hotpath-report-darwin-aarch64",
                    "hotpath-report-linux-aarch64",
                    "hotpath-report-linux-x86_64",
                    "hotpath-report-windows-x86_64.exe",
                )
            ],
        }

    @staticmethod
    def _response(status, body):
        return (
            f"HTTP/2.0 {status} Test\r\ncontent-type: application/json\r\n\r\n"
            + json.dumps(body)
        )

    def _inspect(self, release, request_exit_code=0):
        return inspect_release_api_response(
            self._response(200, release),
            request_exit_code,
            "v0.1.1",
            frozenset(
                {
                    "hotpath-report-darwin-aarch64",
                    "hotpath-report-linux-aarch64",
                    "hotpath-report-linux-x86_64",
                    "hotpath-report-windows-x86_64.exe",
                }
            ),
        )

    def test_parse_version(self):
        self.assertEqual(parse_version('version = "0.1.9"\n'), (0, 1, 9))
        self.assertEqual(format_tag((1, 2, 3)), "v1.2.3")

    def test_reject_noncanonical_versions(self):
        for value in ("01.2.3", "1.2.3-alpha", "latest", "1.2", "1.2.03"):
            with self.subTest(value=value), self.assertRaises(ValueError):
                parse_version(f'version = "{value}"\n')

    def test_reject_duplicate_version(self):
        with self.assertRaises(ValueError):
            parse_version('version = "0.1.0"\nversion = "0.2.0"\n')

    def test_changed_version_triggers_release(self):
        self.assertEqual(
            release_from_change('version = "0.1.0"\n', 'version = "0.2.0"\n'),
            "v0.2.0",
        )

    def test_dependency_change_does_not_trigger_release(self):
        self.assertEqual(
            release_from_change('version = "0.1.0"\nimport = "a"\n',
                                'version = "0.1.0"\nimport = "b"\n'),
            "",
        )

    def test_version_downgrade_rejected(self):
        with self.assertRaisesRegex(ValueError, "decreased"):
            release_from_change('version = "0.4.0"\n', 'version = "0.3.0"\n')

    def test_complete_release_with_all_four_platform_assets_is_idempotent(self):
        self.assertEqual(self._inspect(self._valid_release()), "complete")

    def test_incomplete_or_draft_release_fails_closed(self):
        release = self._valid_release()
        release["assets"].pop()
        with self.assertRaisesRegex(ValueError, "exactly 4"):
            self._inspect(release)
        release = self._valid_release()
        release["draft"] = True
        with self.assertRaisesRegex(ValueError, "draft"):
            self._inspect(release)

    def test_release_lookup_accepts_only_a_real_not_found_response(self):
        self.assertEqual(
            inspect_release_api_response(
                self._response(404, {"message": "Not Found"}),
                1,
                "v0.1.1",
                frozenset(),
            ),
            "missing",
        )
        with self.assertRaisesRegex(ValueError, "HTTP 404"):
            inspect_release_api_response(
                self._response(404, {"message": "Not Found"}),
                0,
                "v0.1.1",
                frozenset(),
            )

    def test_release_list_detects_races_after_a_tag_lookup_misses(self):
        with self.assertRaisesRegex(ValueError, "release list contains"):
            inspect_release_list_response(
                json.dumps([[self._valid_release()]]),
                0,
                "v0.1.1",
            )

if __name__ == "__main__":
    unittest.main()
