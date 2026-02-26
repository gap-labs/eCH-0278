from pathlib import Path
from xml.etree.ElementTree import ParseError

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


def validate_xml(xml_bytes: bytes) -> dict:
    if not xml_bytes:
        return {
            "xsdValid": False,
            "errors": ["XML parse error: empty payload."],
            "namespaces": [],
        }

    try:
        validation_errors = [
            _format_validation_error(error) for error in SCHEMA.iter_errors(xml_bytes)
        ]
    except Exception as exc:
        if isinstance(exc, ParseError):
            message = f"XML parse error: {exc}"
        else:
            message = f"Validation processing error: {exc}"
        return {
            "xsdValid": False,
            "errors": [message],
            "namespaces": [],
        }

    return {
        "xsdValid": len(validation_errors) == 0,
        "errors": validation_errors,
        "namespaces": [],
    }
