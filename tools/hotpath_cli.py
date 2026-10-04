from __future__ import annotations

import argparse
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
from dataclasses import dataclass
from typing import Sequence

RUNTIME_MODULE = "f4ah6o/hotpath"
RUNTIME_PACKAGE = "f4ah6o/hotpath/src"
BUILD_VIEW_REL = Path(".hotpath") / "build-view"
EXCLUDED_DIRS = {
    ".git",
    ".hotpath",
    "_build",
    "target",
    "node_modules",
    ".venv",
    "__pycache__",
}


@dataclass(frozen=True)
class HotpathDiagnostic:
    path: str
    line: int
    column: int
    message: str

    def __str__(self) -> str:
        return f"{self.path}:{self.line}:{self.column}: hotpath: {self.message}"


class HotpathError(Exception):
    def __init__(self, diagnostic: HotpathDiagnostic):
        super().__init__(str(diagnostic))
        self.diagnostic = diagnostic


@dataclass(frozen=True)
class RewriteResult:
    source: str
    instrumented: int
    skipped: int


@dataclass(frozen=True)
class _Marker:
    start: int
    end: int
    label_expr: str | None
    skip: bool
    is_block: bool


@dataclass(frozen=True)
class _Edit:
    start: int
    end: int
    replacement: str


def _line_col(source: str, offset: int) -> tuple[int, int]:
    line = source.count("\n", 0, offset) + 1
    last = source.rfind("\n", 0, offset)
    return line, offset - (last + 1) + 1


def _error(path: str, source: str, offset: int, message: str) -> HotpathError:
    line, col = _line_col(source, offset)
    return HotpathError(HotpathDiagnostic(path, line, col, message))


def _parse_marker_payload(
    path: str, source: str, offset: int, payload: str
) -> tuple[str | None, bool]:
    payload = payload.strip()
    if payload == "":
        return None, False
    if not (payload.startswith("(") and payload.endswith(")")):
        raise _error(
            path,
            source,
            offset,
            'expected #hotpath.measure, #hotpath.measure("label"), or skip=true',
        )
    inner = payload[1:-1].strip()
    if inner == "":
        return None, False

    skip = False
    label_expr: str | None = None
    parts: list[str] = []
    current: list[str] = []
    in_string = False
    escaped = False
    for ch in inner:
        if in_string:
            current.append(ch)
            if escaped:
                escaped = False
            elif ch == "\\":
                escaped = True
            elif ch == '"':
                in_string = False
            continue
        if ch == '"':
            in_string = True
            current.append(ch)
        elif ch == ",":
            parts.append("".join(current).strip())
            current = []
        else:
            current.append(ch)
    if in_string:
        raise _error(path, source, offset, "unterminated string in #hotpath.measure")
    parts.append("".join(current).strip())

    for part in parts:
        if not part:
            raise _error(path, source, offset, "empty #hotpath.measure argument")
        if part == "skip=true":
            skip = True
            continue
        candidate = part
        if part.startswith("label="):
            candidate = part[len("label=") :].strip()
        if candidate.startswith('"') and candidate.endswith('"') and len(candidate) >= 2:
            if label_expr is not None:
                raise _error(
                    path, source, offset, "multiple labels in #hotpath.measure"
                )
            label_expr = candidate
            continue
        raise _error(
            path,
            source,
            offset,
            f"unsupported #hotpath.measure argument {part!r}; "
            "supported arguments are a string label and skip=true",
        )
    return label_expr, skip


def _find_markers(path: str, source: str) -> list[_Marker]:
    markers: list[_Marker] = []
    offset = 0
    attr_re = re.compile(
        r"^(?P<indent>[ \t]*)#hotpath\.measure(?P<payload>[^\r\n]*?)[ \t]*$"
    )
    block_re = re.compile(
        r"^(?P<indent>[ \t]*)//[ \t]*#hotpath\.measure(?P<payload>[^\r\n]*?)[ \t]*$"
    )
    for raw_line in source.splitlines(keepends=True):
        line = raw_line.rstrip("\r\n")
        match = attr_re.match(line)
        is_block = False
        if match is None:
            match = block_re.match(line)
            is_block = match is not None
        if match is not None:
            marker_start = offset + len(match.group("indent"))
            label_expr, skip = _parse_marker_payload(
                path, source, marker_start, match.group("payload")
            )
            markers.append(
                _Marker(
                    start=offset,
                    end=offset + len(line),
                    label_expr=label_expr,
                    skip=skip,
                    is_block=is_block,
                )
            )
        offset += len(raw_line)
    return markers


def _skip_trivia_lines(source: str, offset: int) -> int:
    pos = offset
    n = len(source)
    while pos < n:
        line_end = source.find("\n", pos)
        if line_end < 0:
            line_end = n
        text = source[pos:line_end].strip()
        if (
            text == ""
            or text.startswith("///")
            or text.startswith("//!")
            or (text.startswith("#") and not text.startswith("#hotpath.measure"))
        ):
            pos = line_end + (1 if line_end < n else 0)
            continue
        return pos
    return n


def _fn_name(path: str, source: str, decl_offset: int) -> str:
    line_end = source.find("\n", decl_offset)
    if line_end < 0:
        line_end = len(source)
    first = source[decl_offset:line_end]
    stripped = first.lstrip()
    base = decl_offset + (len(first) - len(stripped))
    if re.search(r"\basync\s+fn\b", stripped):
        fn_pos = base + stripped.find("async")
        raise _error(
            path,
            source,
            fn_pos,
            "async function instrumentation is deferred until M3 defines "
            "async/cancellation finalization; use #hotpath.measure(skip=true)",
        )
    match = re.search(r"\bfn\b", stripped)
    if not match:
        raise _error(
            path,
            source,
            base,
            "#hotpath.measure must annotate a function declaration; use "
            '// #hotpath.measure("label") before an explicit block',
        )
    pos = base + match.end()
    while pos < len(source) and source[pos] in " \t":
        pos += 1
    if pos < len(source) and source[pos] == "[":
        depth = 1
        pos += 1
        while pos < len(source) and depth:
            if source[pos] == "[":
                depth += 1
            elif source[pos] == "]":
                depth -= 1
            pos += 1
        if depth:
            raise _error(
                path,
                source,
                pos - 1,
                "unterminated generic parameter list in annotated function",
            )
        while pos < len(source) and source[pos] in " \t":
            pos += 1
    start = pos
    while pos < len(source) and (source[pos].isalnum() or source[pos] in "_:"):
        pos += 1
    name = source[start:pos]
    if not name:
        raise _error(
            path, source, start, "could not determine annotated function name"
        )
    return name


def _scan_to_body_open(path: str, source: str, start: int) -> int:
    i = start
    paren = 0
    bracket = 0
    block_comment = 0
    in_string: str | None = None
    escaped = False
    while i < len(source):
        ch = source[i]
        nxt = source[i + 1] if i + 1 < len(source) else ""
        if block_comment:
            if ch == "/" and nxt == "*":
                block_comment += 1
                i += 2
                continue
            if ch == "*" and nxt == "/":
                block_comment -= 1
                i += 2
                continue
            i += 1
            continue
        if in_string:
            if escaped:
                escaped = False
            elif ch == "\\":
                escaped = True
            elif ch == in_string:
                in_string = None
            i += 1
            continue
        if ch == "/" and nxt == "/":
            newline = source.find("\n", i + 2)
            if newline < 0:
                break
            i = newline + 1
            continue
        if ch == "/" and nxt == "*":
            block_comment = 1
            i += 2
            continue
        if ch in ('"', "'"):
            in_string = ch
            i += 1
            continue
        if ch == "(":
            paren += 1
        elif ch == ")":
            paren = max(0, paren - 1)
        elif ch == "[":
            bracket += 1
        elif ch == "]":
            bracket = max(0, bracket - 1)
        elif ch == "{" and paren == 0 and bracket == 0:
            return i
        elif ch == "=" and paren == 0 and bracket == 0:
            raise _error(
                path,
                source,
                i,
                "annotated function has no supported block body; add skip=true "
                "or use a function with a { ... } body",
            )
        i += 1
    raise _error(
        path, source, start, "could not find a block body for #hotpath.measure"
    )


def _matching_brace(path: str, source: str, open_pos: int) -> int:
    depth = 0
    block_comment = 0
    in_string: str | None = None
    escaped = False
    i = open_pos
    while i < len(source):
        ch = source[i]
        nxt = source[i + 1] if i + 1 < len(source) else ""
        line_start = i == 0 or source[i - 1] == "\n"
        if not block_comment and not in_string and line_start:
            j = i
            while j < len(source) and source[j] in " \t":
                j += 1
            if source.startswith("#|", j) or source.startswith("$|", j):
                newline = source.find("\n", j + 2)
                if newline < 0:
                    break
                i = newline + 1
                continue
        if block_comment:
            if ch == "/" and nxt == "*":
                block_comment += 1
                i += 2
                continue
            if ch == "*" and nxt == "/":
                block_comment -= 1
                i += 2
                continue
            i += 1
            continue
        if in_string:
            if escaped:
                escaped = False
            elif ch == "\\":
                escaped = True
            elif ch == in_string:
                in_string = None
            i += 1
            continue
        if ch == "/" and nxt == "/":
            newline = source.find("\n", i + 2)
            if newline < 0:
                break
            i = newline + 1
            continue
        if ch == "/" and nxt == "*":
            block_comment = 1
            i += 2
            continue
        if ch in ('"', "'"):
            in_string = ch
            i += 1
            continue
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return i
            if depth < 0:
                break
        i += 1
    raise _error(path, source, open_pos, "unterminated block for #hotpath.measure")


def _quote_label(name: str) -> str:
    escaped = name.replace("\\", "\\\\").replace('"', '\\"')
    return f'"{escaped}"'


def rewrite_source(path: str, source: str) -> RewriteResult:
    markers = _find_markers(path, source)
    edits: list[_Edit] = []
    instrumented = 0
    skipped = 0

    for marker in markers:
        after_marker = source.find("\n", marker.end)
        after_marker = len(source) if after_marker < 0 else after_marker + 1
        target = _skip_trivia_lines(source, after_marker)
        if marker.skip:
            skipped += 1
            if not marker.is_block:
                original_line = source[marker.start : marker.end]
                original = original_line.lstrip()
                indent = original_line[: len(original_line) - len(original)]
                edits.append(
                    _Edit(
                        marker.start,
                        marker.end,
                        f"{indent}// hotpath: skipped {original}",
                    )
                )
            continue

        if marker.is_block:
            line_end = source.find("\n", target)
            if line_end < 0:
                line_end = len(source)
            target_line = source[target:line_end]
            indent_len = len(target_line) - len(target_line.lstrip(" \t"))
            open_pos = target + indent_len
            if open_pos >= len(source) or source[open_pos] != "{":
                raise _error(
                    path,
                    source,
                    target,
                    "block directive must be followed by an explicit { ... } block; "
                    "use #hotpath.measure on a function",
                )
            label = marker.label_expr
            if label is None:
                raise _error(
                    path,
                    source,
                    marker.start,
                    "explicit block instrumentation requires a string label",
                )
            close_pos = _matching_brace(path, source, open_pos)
            prefix = source[marker.start : marker.end].split("//", 1)[0]
            edits.extend(
                [
                    _Edit(
                        marker.start,
                        marker.end,
                        prefix + "// hotpath: instrumented block",
                    ),
                    _Edit(
                        open_pos,
                        open_pos + 1,
                        f"@hotpath.measure_global({label}, fn() {{",
                    ),
                    _Edit(close_pos, close_pos + 1, "})"),
                ]
            )
            instrumented += 1
            continue

        name = _fn_name(path, source, target)
        open_pos = _scan_to_body_open(path, source, target)
        close_pos = _matching_brace(path, source, open_pos)
        label = marker.label_expr or _quote_label(name)
        original_line = source[marker.start : marker.end]
        original = original_line.lstrip()
        indent = original_line[: len(original_line) - len(original)]
        edits.extend(
            [
                _Edit(
                    marker.start,
                    marker.end,
                    f"{indent}// hotpath: instrumented {original}",
                ),
                _Edit(
                    open_pos + 1,
                    open_pos + 1,
                    f" @hotpath.measure_global({label}, fn() {{",
                ),
                _Edit(close_pos, close_pos, "}) "),
            ]
        )
        instrumented += 1

    edits.sort(key=lambda edit: (edit.start, edit.end), reverse=True)
    last_start = len(source) + 1
    result = source
    for edit in edits:
        if edit.end > last_start:
            raise _error(
                path,
                source,
                edit.start,
                "overlapping hotpath rewrite directives are unsupported",
            )
        result = result[: edit.start] + edit.replacement + result[edit.end :]
        last_start = edit.start
    return RewriteResult(result, instrumented, skipped)


def _module_has_runtime_dependency(project: Path) -> bool:
    moon_mod = project / "moon.mod"
    if moon_mod.exists():
        text = moon_mod.read_text(encoding="utf-8")
        if re.search(
            r'^\s*name\s*=\s*"f4ah6o/hotpath"\s*$', text, re.MULTILINE
        ):
            return True
        return '"f4ah6o/hotpath@' in text or '"f4ah6o/hotpath"' in text
    legacy = project / "moon.mod.json"
    if legacy.exists():
        import json

        data = json.loads(legacy.read_text(encoding="utf-8"))
        if data.get("name") == RUNTIME_MODULE:
            return True
        return RUNTIME_MODULE in (data.get("deps") or {})
    raise HotpathError(
        HotpathDiagnostic(
            str(project), 1, 1, "no moon.mod or moon.mod.json found"
        )
    )


def _inject_runtime_import(pkg: Path) -> None:
    if not pkg.exists():
        raise HotpathError(
            HotpathDiagnostic(
                str(pkg),
                1,
                1,
                "instrumented source is not in a MoonBit package with moon.pkg",
            )
        )
    text = pkg.read_text(encoding="utf-8")
    if f'"{RUNTIME_PACKAGE}"' in text:
        return
    suffix = "" if text.endswith("\n") else "\n"
    text += (
        suffix
        + f'\nimport {{\n  "{RUNTIME_PACKAGE}" @hotpath,\n}}\n'
    )
    pkg.write_text(text, encoding="utf-8", newline="\n")


def generate_build_view(project: Path) -> tuple[Path, int, int]:
    project = project.resolve()
    if not _module_has_runtime_dependency(project):
        raise HotpathError(
            HotpathDiagnostic(
                str(project / "moon.mod"),
                1,
                1,
                "module does not depend on f4ah6o/hotpath; run "
                "\`moon add f4ah6o/hotpath\` before using source instrumentation",
            )
        )
    out = project / BUILD_VIEW_REL
    if out.exists():
        shutil.rmtree(out)
    out.mkdir(parents=True, exist_ok=True)

    instrumented_dirs: set[Path] = set()
    total = 0
    skipped = 0
    for root, dirs, files in os.walk(project):
        root_path = Path(root)
        dirs[:] = [d for d in sorted(dirs) if d not in EXCLUDED_DIRS]
        if root_path == out or out in root_path.parents:
            dirs[:] = []
            continue
        rel_root = root_path.relative_to(project)
        dest_root = out / rel_root
        dest_root.mkdir(parents=True, exist_ok=True)
        for name in sorted(files):
            src = root_path / name
            rel = src.relative_to(project)
            dest = out / rel
            if name.endswith(".mbt.md"):
                text = src.read_text(encoding="utf-8")
                if "#hotpath.measure" in text:
                    raise HotpathError(
                        HotpathDiagnostic(
                            str(src),
                            1,
                            1,
                            "instrumentation inside .mbt.md is not supported in M2; "
                            "move the annotated code to a .mbt source file",
                        )
                    )
                shutil.copyfile(src, dest)
            elif name.endswith(".mbt"):
                text = src.read_text(encoding="utf-8")
                rewritten = rewrite_source(str(src), text)
                dest.write_text(
                    rewritten.source, encoding="utf-8", newline=""
                )
                total += rewritten.instrumented
                skipped += rewritten.skipped
                if rewritten.instrumented:
                    instrumented_dirs.add(rel_root)
            else:
                shutil.copyfile(src, dest)

    for rel_dir in sorted(instrumented_dirs):
        legacy = out / rel_dir / "moon.pkg.json"
        pkg = out / rel_dir / "moon.pkg"
        if legacy.exists() and not pkg.exists():
            raise HotpathError(
                HotpathDiagnostic(
                    str(project / rel_dir / "moon.pkg.json"),
                    1,
                    1,
                    "legacy moon.pkg.json injection is intentionally unsupported; "
                    "run \`moon fmt\` to migrate to moon.pkg",
                )
            )
        _inject_runtime_import(pkg)
    return out, total, skipped


def clean_build_view(project: Path) -> bool:
    out = project.resolve() / BUILD_VIEW_REL
    if out.exists():
        shutil.rmtree(out)
        return True
    return False


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="hotpath",
        description="Opt-in source instrumentation build view for hotpath.mbt",
    )
    sub = parser.add_subparsers(dest="command", required=True)
    for command in ("view", "clean"):
        subparser = sub.add_parser(command)
        subparser.add_argument("project", nargs="?", default=".")
    build = sub.add_parser("build")
    build.add_argument("project", nargs="?", default=".")
    build.add_argument("moon_args", nargs=argparse.REMAINDER)
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = _parser().parse_args(argv)
    try:
        project = Path(args.project)
        if args.command == "clean":
            removed = clean_build_view(project)
            state = "removed" if removed else "no"
            print(
                f"hotpath: {state} build view: "
                f"{project.resolve() / BUILD_VIEW_REL}"
            )
            return 0

        out, count, skipped = generate_build_view(project)
        print(
            f"hotpath: build view {out} "
            f"({count} instrumented, {skipped} skipped)"
        )
        if args.command == "view":
            return 0

        moon_args = list(args.moon_args)
        if moon_args and moon_args[0] == "--":
            moon_args = moon_args[1:]
        completed = subprocess.run(
            ["moon", "build", *moon_args], cwd=out, check=False
        )
        return completed.returncode
    except HotpathError as exc:
        print(exc, file=sys.stderr)
        return 2
    except OSError as exc:
        print(f"hotpath: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
