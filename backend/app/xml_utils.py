import io
from collections import defaultdict
from xml.etree import ElementTree as ET


def local_name(tag: str) -> str:
    if "}" in tag:
        return tag.split("}", 1)[1]
    return tag


def parse_xml_once(xml_bytes: bytes) -> tuple[ET.Element | None, list[dict], str | None]:
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


def collect_leaf_values(root: ET.Element) -> dict[str, list[str]]:
    leaf_values: dict[str, list[str]] = defaultdict(list)

    def visit(node: ET.Element, path: str) -> None:
        children = list(node)
        if not children:
            value = (node.text or "").strip()
            leaf_values[path].append(value)
            return

        for child in children:
            child_name = local_name(child.tag)
            child_path = f"{path}/{child_name}"
            visit(child, child_path)

    root_name = local_name(root.tag)
    visit(root, root_name)
    return dict(leaf_values)