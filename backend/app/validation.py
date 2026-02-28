import tempfile
import time
from pathlib import Path
from threading import Lock
from xml.etree import ElementTree as ET

import xmlschema
from saxonche import PySaxonProcessor, PyXsltExecutable
from app.xml_utils import parse_xml_once


SCHEMA_PATH = Path(__file__).resolve().parents[1] / "schema" / "eCH-0278-1-0.xsd"
VENDORED_SCHEMA_DIR = Path(__file__).resolve().parents[1] / "schema" / "vendor"
GENERATED_SCHEMATRON_DIR = Path(__file__).resolve().parent / "generated" / "schematron"
SVRL_NS = {"svrl": "http://purl.oclc.org/dsdl/svrl"}

_schema_lock = Lock()
_schema: xmlschema.XMLSchema | None = None


_procedural_lock = Lock()
_procedural_initialized = False
_procedural_init_error: str | None = None
_procedural_processor: PySaxonProcessor | None = None
_procedural_executables: list[dict] = []


def _schema_locations_from_vendor() -> list[tuple[str, str]]:
    if not VENDORED_SCHEMA_DIR.exists():
        return []

    locations: dict[str, str] = {}
    for schema_file in sorted(VENDORED_SCHEMA_DIR.rglob("*.xsd")):
        try:
            schema_root = ET.parse(schema_file).getroot()
        except ET.ParseError:
            continue

        target_namespace = schema_root.attrib.get("targetNamespace")
        if target_namespace and target_namespace not in locations:
            locations[target_namespace] = str(schema_file)

    return list(locations.items())


def _get_schema() -> xmlschema.XMLSchema:
    global _schema

    if _schema is not None:
        return _schema

    with _schema_lock:
        if _schema is not None:
            return _schema

        last_error: Exception | None = None
        schema_locations = _schema_locations_from_vendor()
        for attempt in range(1, 4):
            try:
                if schema_locations:
                    _schema = xmlschema.XMLSchema(str(SCHEMA_PATH), locations=schema_locations)
                else:
                    _schema = xmlschema.XMLSchema(str(SCHEMA_PATH))
                return _schema
            except Exception as exc:
                last_error = exc
                if attempt < 3:
                    time.sleep(1)

        raise RuntimeError(f"Failed to load XSD schema at {SCHEMA_PATH}: {last_error}") from last_error


def _format_validation_error(error: object) -> str:
    path = getattr(error, "path", None)
    reason = getattr(error, "reason", None)
    if path and reason:
        return f"{path}: {reason}"
    if reason:
        return str(reason)
    return str(error)


def _build_response(
    *,
    xsd_valid: bool,
    structural_errors: list[str],
    namespaces: list[dict],
    analysis: dict,
    procedural_findings: list[dict],
    procedural_available: bool | None = None,
) -> dict:
    response = {
        "xsdValid": xsd_valid,
        "structuralErrors": structural_errors,
        "proceduralFindings": procedural_findings,
        "errors": structural_errors,
        "namespaces": namespaces,
        "analysis": analysis,
    }
    if procedural_available is not None:
        response["proceduralAvailable"] = procedural_available
    return response


def _procedural_availability_status() -> tuple[bool, str | None]:
    initialize_procedural_validators()

    if _procedural_init_error:
        return False, _procedural_init_error
    if not _procedural_executables:
        return False, "No compiled procedural validator stylesheets found."
    return True, None


def _axis_from_code(code: str) -> str:
    lowered = code.lower()
    if lowered.startswith("time_") or "time" in lowered:
        return "time"
    if lowered.startswith("transfer_") or "transfer" in lowered or "actor" in lowered:
        return "transfer"
    return "none"


def _normalize_severity(raw_value: str | None) -> str:
    if not raw_value:
        return "error"
    lowered = raw_value.lower()
    if lowered in {"fatal", "error"}:
        return "error"
    if lowered == "warning":
        return "warning"
    return "info"


def _extract_text(node: ET.Element | None) -> str:
    if node is None:
        return "Procedural validation finding detected."
    text = "".join(node.itertext()).strip()
    return text or "Procedural validation finding detected."


def _rule_version_for(stylesheet_path: Path) -> str | None:
    for candidate in [stylesheet_path.parent / "VERSION", stylesheet_path.parent.parent / "VERSION"]:
        if candidate.exists():
            try:
                value = candidate.read_text(encoding="utf-8").strip()
                if value:
                    return value
            except OSError:
                return None
    return None


def _to_findings_from_svrl(
    svrl_text: str,
    *,
    stylesheet_path: Path,
    rule_version: str | None,
) -> list[dict]:
    findings: list[dict] = []

    try:
        svrl_root = ET.fromstring(svrl_text)
    except ET.ParseError as exc:
        return [
            {
                "code": "procedural_svrl_parse_error",
                "ruleVersion": rule_version,
                "severity": "error",
                "layer": "procedural",
                "axis": "none",
                "message": f"SVRL parse error for stylesheet '{stylesheet_path.name}': {exc}",
                "paths": [],
            }
        ]

    for element_name in ("failed-assert", "successful-report", "error"):
        for node in svrl_root.findall(f".//svrl:{element_name}", SVRL_NS):
            role_value = node.attrib.get("role")
            severity_value = node.attrib.get("severity") or node.attrib.get("flag") or role_value
            code = (
                node.attrib.get("id")
                or node.attrib.get("flag")
                or role_value
                or f"{stylesheet_path.stem}_{element_name}"
            )
            location = node.attrib.get("location")
            message = _extract_text(node.find("svrl:text", SVRL_NS))
            findings.append(
                {
                    "code": code,
                    "ruleVersion": rule_version,
                    "severity": _normalize_severity(severity_value),
                    "layer": "procedural",
                    "axis": _axis_from_code(code),
                    "message": message,
                    "paths": [location] if location else [],
                }
            )

    return findings


def initialize_procedural_validators() -> None:
    global _procedural_initialized
    global _procedural_init_error
    global _procedural_processor
    global _procedural_executables

    with _procedural_lock:
        if _procedural_initialized:
            return

        _procedural_executables = []
        _procedural_init_error = None

        try:
            _procedural_processor = PySaxonProcessor(license=False)
            xslt30 = _procedural_processor.new_xslt30_processor()

            if GENERATED_SCHEMATRON_DIR.exists():
                stylesheet_paths = sorted(GENERATED_SCHEMATRON_DIR.rglob("*.xsl"))
                for stylesheet_path in stylesheet_paths:
                    executable: PyXsltExecutable = xslt30.compile_stylesheet(
                        stylesheet_file=str(stylesheet_path)
                    )
                    _procedural_executables.append(
                        {
                            "stylesheet": stylesheet_path,
                            "ruleVersion": _rule_version_for(stylesheet_path),
                            "executable": executable,
                        }
                    )
        except Exception as exc:
            _procedural_init_error = f"Procedural validator initialization failed: {exc}"
        finally:
            _procedural_initialized = True


def _run_procedural_validation(xml_bytes: bytes) -> list[dict]:
    procedural_available, unavailable_message = _procedural_availability_status()
    if not procedural_available:
        return [
            {
                "code": "procedural_validator_unavailable",
                "ruleVersion": None,
                "severity": "error",
                "layer": "procedural",
                "axis": "none",
                "message": unavailable_message,
                "paths": [],
            }
        ]

    findings: list[dict] = []
    with tempfile.NamedTemporaryFile(suffix=".xml", delete=False) as temp_file:
        temp_file.write(xml_bytes)
        temp_path = Path(temp_file.name)
    try:
        for item in _procedural_executables:
            stylesheet_path = item["stylesheet"]
            executable: PyXsltExecutable = item["executable"]
            rule_version: str | None = item["ruleVersion"]

            try:
                svrl_text = executable.transform_to_string(source_file=str(temp_path))
                findings.extend(
                    _to_findings_from_svrl(
                        svrl_text,
                        stylesheet_path=stylesheet_path,
                        rule_version=rule_version,
                    )
                )
            except Exception as exc:
                findings.append(
                    {
                        "code": "procedural_validation_runtime_error",
                        "ruleVersion": rule_version,
                        "severity": "error",
                        "layer": "procedural",
                        "axis": "none",
                        "message": (
                            f"Procedural validation failed for stylesheet '{stylesheet_path.name}': {exc}"
                        ),
                        "paths": [],
                    }
                )
    finally:
        try:
            temp_path.unlink(missing_ok=True)
        except OSError:
            pass

    return findings


def validate_xml(xml_bytes: bytes, procedural: bool = False) -> dict:
    namespaces: list[dict] = []
    analysis = {
        "taxProceduresFound": [],
        "phaseDetected": "unknown",
        "snapshotWarning": False,
    }
    procedural_available: bool | None = None

    if procedural:
        procedural_available, _ = _procedural_availability_status()

    if not xml_bytes:
        return _build_response(
            xsd_valid=False,
            structural_errors=["XML parse error: empty payload."],
            namespaces=namespaces,
            analysis=analysis,
            procedural_findings=[],
            procedural_available=procedural_available,
        )

    root, parsed_namespaces, parse_error = parse_xml_once(xml_bytes)
    if parsed_namespaces:
        namespaces = parsed_namespaces

    analysis = _detect_tax_procedures(root)

    if parse_error:
        return _build_response(
            xsd_valid=False,
            structural_errors=[parse_error],
            namespaces=namespaces,
            analysis=analysis,
            procedural_findings=[],
            procedural_available=procedural_available,
        )

    try:
        schema = _get_schema()
        validation_errors = [
            _format_validation_error(error) for error in schema.iter_errors(xml_bytes)
        ]
    except Exception as exc:
        if isinstance(exc, ET.ParseError):
            message = f"XML parse error: {exc}"
        else:
            message = f"Validation processing error: {exc}"
        return _build_response(
            xsd_valid=False,
            structural_errors=[message],
            namespaces=namespaces,
            analysis=analysis,
            procedural_findings=[],
            procedural_available=procedural_available,
        )

    xsd_valid = len(validation_errors) == 0
    procedural_findings: list[dict] = []
    if procedural and xsd_valid:
        procedural_findings = _run_procedural_validation(xml_bytes)

    return _build_response(
        xsd_valid=xsd_valid,
        structural_errors=validation_errors,
        namespaces=namespaces,
        analysis=analysis,
        procedural_findings=procedural_findings,
        procedural_available=procedural_available,
    )


def close_procedural_validators() -> None:
    global _procedural_initialized
    global _procedural_init_error
    global _procedural_processor
    global _procedural_executables

    with _procedural_lock:
        processor = _procedural_processor
        _procedural_processor = None
        _procedural_executables = []
        _procedural_init_error = None
        _procedural_initialized = False

        if processor is not None:
            release_method = getattr(processor, "release", None)
            if callable(release_method):
                try:
                    release_method()
                except Exception:
                    pass


def _detect_tax_procedures(root: ET.Element | None) -> dict:
    if root is None:
        return {
            "taxProceduresFound": [],
            "phaseDetected": "unknown",
            "snapshotWarning": False,
        }

    procedures = set()

    for elem in root.iter():
        value = elem.attrib.get("taxProcedure")
        if value:
            procedures.add(value)

    if not procedures:
        phase = "unknown"
    elif procedures == {"declaration"}:
        phase = "declaration"
    elif procedures == {"taxation"}:
        phase = "taxation"
    else:
        phase = "mixed"

    return {
        "taxProceduresFound": sorted(list(procedures)),
        "phaseDetected": phase,
        "snapshotWarning": phase == "mixed",
    }