from __future__ import annotations

from pathlib import Path
import tempfile
import unittest

from tools.hotpath_cli import (
    HotpathError,
    clean_build_view,
    generate_build_view,
    rewrite_source,
)


class RewriteTests(unittest.TestCase):
    def test_function_instrumentation_preserves_line_count(self) -> None:
        source = """#hotpath.measure
pub fn parse(x : Int) -> Int {
  let y = x + 1
  y * 2
}
"""
        result = rewrite_source("src/main.mbt", source)
        self.assertEqual(result.instrumented, 1)
        self.assertEqual(source.count("\n"), result.source.count("\n"))
        self.assertIn(
            "// hotpath: instrumented #hotpath.measure", result.source
        )
        self.assertIn(
            '{@hotpath.measure_global("parse"', result.source.replace(" ", "")
        )
        self.assertIn("}) }", result.source)

    def test_generic_method_uses_qualified_default_label(self) -> None:
        source = """#hotpath.measure
pub fn[T] Worker::run(self : Worker, value : T) -> T {
  value
}
"""
        result = rewrite_source("src/main.mbt", source)
        self.assertIn(
            '@hotpath.measure_global("Worker::run", fn() {', result.source
        )

    def test_explicit_label_and_nested_block(self) -> None:
        source = """#hotpath.measure("outer")
fn work(x : Int) -> Int {
  // #hotpath.measure("inner")
  {
    x + 1
  }
}
"""
        result = rewrite_source("src/main.mbt", source)
        self.assertEqual(result.instrumented, 2)
        self.assertIn(
            '@hotpath.measure_global("outer", fn() {', result.source
        )
        self.assertIn(
            '@hotpath.measure_global("inner", fn() {', result.source
        )
        self.assertEqual(source.count("\n"), result.source.count("\n"))

    def test_skip_is_escape_hatch(self) -> None:
        source = """#hotpath.measure(skip=true)
async fn work() -> Unit {
  ()
}
"""
        result = rewrite_source("src/main.mbt", source)
        self.assertEqual(result.instrumented, 0)
        self.assertEqual(result.skipped, 1)
        self.assertNotIn("measure_global", result.source)
        self.assertIn("hotpath: skipped", result.source)

    def test_rewrite_is_reproducible(self) -> None:
        source = '#hotpath.measure(label="same")\nfn f() -> Int { 1 }\n'
        first = rewrite_source("a.mbt", source).source
        second = rewrite_source("a.mbt", source).source
        self.assertEqual(first, second)

    def test_unsupported_target_fails_closed_with_source_location(self) -> None:
        source = "#hotpath.measure\nlet value = 1\n"
        with self.assertRaises(HotpathError) as ctx:
            rewrite_source("src/main.mbt", source)
        self.assertIn("src/main.mbt:2:1", str(ctx.exception))
        self.assertIn("must annotate a function", str(ctx.exception))

    def test_async_function_fails_closed(self) -> None:
        source = "#hotpath.measure\nasync fn work() -> Unit { () }\n"
        with self.assertRaises(HotpathError) as ctx:
            rewrite_source("src/main.mbt", source)
        self.assertIn("deferred until M3", str(ctx.exception))
        self.assertIn("skip=true", str(ctx.exception))

    def test_braces_in_strings_and_comments_do_not_end_function(self) -> None:
        source = """#hotpath.measure
fn f() -> String {
  // } not the end
  let x = "{still text}"
  x
}
"""
        result = rewrite_source("src/main.mbt", source)
        self.assertTrue(result.source.rstrip().endswith("}) }"))


class BuildViewTests(unittest.TestCase):
    def _project(self, root: Path) -> Path:
        (root / "moon.mod").write_text(
            'name = "example/app"\n\n'
            'import {\n  "f4ah6o/hotpath@0.1.0"\n}\n',
            encoding="utf-8",
        )
        pkg = root / "src"
        pkg.mkdir()
        (pkg / "moon.pkg").write_text(
            'pkgtype(kind: "library")\n', encoding="utf-8"
        )
        (pkg / "main.mbt").write_text(
            "#hotpath.measure\n"
            "pub fn work() -> Int {\n"
            "  42\n"
            "}\n",
            encoding="utf-8",
        )
        return root

    def test_build_view_is_non_destructive_and_injects_runtime_import(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            project = self._project(Path(td))
            canonical = (project / "src/main.mbt").read_bytes()
            out, count, skipped = generate_build_view(project)
            self.assertEqual((count, skipped), (1, 0))
            self.assertEqual(
                (project / "src/main.mbt").read_bytes(), canonical
            )
            generated = (out / "src/main.mbt").read_text(encoding="utf-8")
            self.assertIn("@hotpath.measure_global", generated)
            pkg = (out / "src/moon.pkg").read_text(encoding="utf-8")
            self.assertIn('"f4ah6o/hotpath/src" @hotpath', pkg)

    def test_build_view_recreation_removes_stale_artifacts(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            project = self._project(Path(td))
            out, _, _ = generate_build_view(project)
            stale = out / "stale.txt"
            stale.write_text("stale", encoding="utf-8")
            out2, _, _ = generate_build_view(project)
            self.assertEqual(out, out2)
            self.assertFalse(stale.exists())

    def test_clean_has_deterministic_location(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            project = self._project(Path(td))
            out, _, _ = generate_build_view(project)
            self.assertTrue(out.exists())
            self.assertTrue(clean_build_view(project))
            self.assertFalse(out.exists())
            self.assertFalse(clean_build_view(project))

    def test_missing_runtime_dependency_is_actionable(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            project = Path(td)
            (project / "moon.mod").write_text(
                'name = "example/app"\n', encoding="utf-8"
            )
            with self.assertRaises(HotpathError) as ctx:
                generate_build_view(project)
            self.assertIn(
                "moon add f4ah6o/hotpath", str(ctx.exception)
            )


if __name__ == "__main__":
    unittest.main()
