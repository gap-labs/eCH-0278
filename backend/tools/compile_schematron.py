from __future__ import annotations

import argparse
from pathlib import Path

from saxonche import PySaxonProcessor


def _matches_any_glob(path: Path, patterns: list[str]) -> bool:
    return any(path.match(pattern) for pattern in patterns)


def compile_schematron(
    source_dir: Path,
    output_dir: Path,
    compiler_xsl: Path,
    include_globs: list[str],
    exclude_globs: list[str],
) -> int:
    if not compiler_xsl.exists():
        raise FileNotFoundError(
            f"SchXslt compiler stylesheet not found: {compiler_xsl}. "
            "Expected transpile.xsl at this path."
        )

    schematron_files = sorted(source_dir.rglob("*.sch"))
    filtered_schematron_files: list[Path] = []
    for schematron_file in schematron_files:
        relative_path = schematron_file.relative_to(source_dir)
        if include_globs and not _matches_any_glob(relative_path, include_globs):
            continue
        if exclude_globs and _matches_any_glob(relative_path, exclude_globs):
            continue
        filtered_schematron_files.append(schematron_file)

    output_dir.mkdir(parents=True, exist_ok=True)

    if not filtered_schematron_files:
        return 0

    compiled_count = 0
    with PySaxonProcessor(license=False) as processor:
        xslt_processor = processor.new_xslt30_processor()

        for schematron_file in filtered_schematron_files:
            relative_path = schematron_file.relative_to(source_dir)
            output_file = (output_dir / relative_path).with_suffix(".xsl")
            output_file.parent.mkdir(parents=True, exist_ok=True)

            xslt_processor.transform_to_file(
                stylesheet_file=str(compiler_xsl),
                source_file=str(schematron_file),
                output_file=str(output_file),
            )
            compiled_count += 1

    return compiled_count


def main() -> None:
    parser = argparse.ArgumentParser(description="Compile Schematron rules to XSLT using SchXslt.")
    parser.add_argument("--source-dir", required=True, type=Path, help="Directory containing .sch files")
    parser.add_argument("--output-dir", required=True, type=Path, help="Directory to write compiled .xsl files")
    parser.add_argument(
        "--compiler-xsl",
        required=True,
        type=Path,
        help="Path to SchXslt transpile.xsl stylesheet",
    )
    parser.add_argument(
        "--include-glob",
        action="append",
        default=[],
        help=(
            "Optional glob pattern relative to --source-dir to include .sch files. "
            "Can be provided multiple times."
        ),
    )
    parser.add_argument(
        "--exclude-glob",
        action="append",
        default=[],
        help=(
            "Optional glob pattern relative to --source-dir to exclude .sch files. "
            "Can be provided multiple times."
        ),
    )
    args = parser.parse_args()

    compiled = compile_schematron(
        args.source_dir,
        args.output_dir,
        args.compiler_xsl,
        args.include_glob,
        args.exclude_glob,
    )
    print(f"Compiled {compiled} Schematron file(s).")


if __name__ == "__main__":
    main()
