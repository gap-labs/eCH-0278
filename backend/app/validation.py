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


def _extract_namespaces(xml_bytes: bytes) -> list[dict]:
    namespaces: dict[str, str] = {}

    try:
        for _, ns in ET.iterparse(io.BytesIO(xml_bytes), events=("start-ns",)):
            prefix, uri = ns
            key = prefix or ""
            if key not in namespaces:
                namespaces[key] = uri
    except ET.ParseError:
        pass

    return [
        {"prefix": prefix, "uri": uri}
        for prefix, uri in sorted(namespaces.items(), key=lambda item: (item[0], item[1]))
    ]


def validate_xml(xml_bytes: bytes) -> dict:
    namespaces = _extract_namespaces(xml_bytes)

    if not xml_bytes:
        return {
            "xsdValid": False,
            "errors": ["XML parse error: empty payload."],
            "namespaces": namespaces,
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
        }

    return {
        "xsdValid": len(validation_errors) == 0,
        "errors": validation_errors,
        "namespaces": namespaces,
    }
