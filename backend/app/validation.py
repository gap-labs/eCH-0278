import io
from pathlib import Path
from xml.etree import ElementTree as ET

import xmlschema


SCHEMA_PATH = Path(__file__).resolve().parents[1] / "schema" / "eCH-0278-1-0.xsd"
try:
    SCHEMA = xmlschema.XMLSchema(str(SCHEMA_PATH))
except Exception as exc:
    raise RuntimeError(f"Failed to load XSD schema at {SCHEMA_PATH}: {exc}") from exc


def _format_validation_error(error: object) -> str:
    path = getattr(error, "path", None)
    reason = getattr(error, "reason", None)
    if path and reason:
        return f"{path}: {reason}"
    if reason:
        return str(reason)
    return str(error)


def _parse_xml_once(xml_bytes: bytes) -> tuple[ET.Element | None, list[dict], str | None]:
    namespaces: dict[str, str] = {}

    try:
        stream = io.BytesIO(xml_bytes)
        parser = ET.iterparse(stream, events=("start", "start-ns"))
        for event, data in parser:
            if event == "start-ns":
                prefix, uri = data
                key = prefix or ""
                if key not in namespaces:
                    namespaces[key] = uri

        root = parser.root
        ordered_namespaces = [
            {"prefix": prefix, "uri": uri}
            for prefix, uri in sorted(namespaces.items(), key=lambda item: (item[0], item[1]))
        ]
        return root, ordered_namespaces, None
    except ET.ParseError as exc:
        ordered_namespaces = [
            {"prefix": prefix, "uri": uri}
            for prefix, uri in sorted(namespaces.items(), key=lambda item: (item[0], item[1]))
        ]
        return None, ordered_namespaces, f"XML parse error: {exc}"


def validate_xml(xml_bytes: bytes) -> dict:
    namespaces: list[dict] = []
    analysis = {
        "taxProceduresFound": [],
        "phaseDetected": "unknown",
        "snapshotWarning": False,
    }

    if not xml_bytes:
        return {
            "xsdValid": False,
            "errors": ["XML parse error: empty payload."],
            "namespaces": namespaces,
            "analysis": analysis,
        }

    root, parsed_namespaces, parse_error = _parse_xml_once(xml_bytes)
    if parsed_namespaces:
        namespaces = parsed_namespaces

    analysis = _detect_tax_procedures(root)

    if parse_error:
        return {
            "xsdValid": False,
            "errors": [parse_error],
            "namespaces": namespaces,
            "analysis": analysis,
        }

    try:
        validation_errors = [
            _format_validation_error(error) for error in SCHEMA.iter_errors(xml_bytes)
        ]
    except Exception as exc:
        if isinstance(exc, ET.ParseError):
            message = f"XML parse error: {exc}"
        else:
            message = f"Validation processing error: {exc}"
        return {
            "xsdValid": False,
            "errors": [message],
            "namespaces": namespaces,
            "analysis": analysis,
        }

    return {
        "xsdValid": len(validation_errors) == 0,
        "errors": validation_errors,
        "namespaces": namespaces,
        "analysis": analysis,
    }


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