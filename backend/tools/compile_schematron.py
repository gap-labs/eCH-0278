from __future__ import annotations

import argparse
from pathlib import Path

from saxonche import PySaxonProcessor


def compile_schematron(source_dir: Path, output_dir: Path, compiler_xsl: Path) -> int:
    if not compiler_xsl.exists():
        raise FileNotFoundError(
            f"SchXslt compiler stylesheet not found: {compiler_xsl}. "
            "Expected compile-for-svrl.xsl at this path."
        )

    schematron_files = sorted(source_dir.rglob("*.sch"))
    output_dir.mkdir(parents=True, exist_ok=True)

    if not schematron_files:
        return 0

    compiled_count = 0
    with PySaxonProcessor(license=False) as processor:
        xslt_processor = processor.new_xslt30_processor()

        for schematron_file in schematron_files:
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
        help="Path to SchXslt compile-for-svrl.xsl stylesheet",
    )
    args = parser.parse_args()

    compiled = compile_schematron(args.source_dir, args.output_dir, args.compiler_xsl)
    print(f"Compiled {compiled} Schematron file(s).")


if __name__ == "__main__":
    main()
