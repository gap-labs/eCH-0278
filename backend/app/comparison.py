from xml.etree import ElementTree as ET

from app.validation import validate_xml
from app.xml_utils import collect_leaf_values, parse_xml_once


def _diff_leaf_values(xml1_root: ET.Element, xml2_root: ET.Element) -> dict:
    xml1_leaves = collect_leaf_values(xml1_root)
    xml2_leaves = collect_leaf_values(xml2_root)

    changed_values = 0
    added_nodes = 0
    removed_nodes = 0

    all_paths = set(xml1_leaves.keys()) | set(xml2_leaves.keys())
    for path in all_paths:
        values1 = xml1_leaves.get(path, [])
        values2 = xml2_leaves.get(path, [])

        shared_count = min(len(values1), len(values2))
        for index in range(shared_count):
            if values1[index] != values2[index]:
                changed_values += 1

        if len(values2) > len(values1):
            added_nodes += len(values2) - len(values1)
        elif len(values1) > len(values2):
            removed_nodes += len(values1) - len(values2)

    return {
        "changedValues": changed_values,
        "addedNodes": added_nodes,
        "removedNodes": removed_nodes,
    }


def compare_xml(xml1_bytes: bytes, xml2_bytes: bytes) -> dict:
    xml1_validation = validate_xml(xml1_bytes)
    xml2_validation = validate_xml(xml2_bytes)

    xml1_root, _, xml1_parse_error = parse_xml_once(xml1_bytes)
    xml2_root, _, xml2_parse_error = parse_xml_once(xml2_bytes)

    if xml1_parse_error or xml2_parse_error or xml1_root is None or xml2_root is None:
        diff_summary = {
            "changedValues": 0,
            "addedNodes": 0,
            "removedNodes": 0,
        }
    else:
        diff_summary = _diff_leaf_values(xml1_root, xml2_root)

    return {
        "xml1Valid": xml1_validation["xsdValid"],
        "xml2Valid": xml2_validation["xsdValid"],
        "diffSummary": diff_summary,
    }