from pathlib import Path
from xml.etree import ElementTree as ET


SCHEMA_FILE = "eCH-0278-1-0.xsd"
SCHEMA_PATH = Path(__file__).resolve().parents[1] / "schema" / SCHEMA_FILE
XS_NS = "http://www.w3.org/2001/XMLSchema"
NS = {"xs": XS_NS}
HIGHLIGHT_GROUPS = {"taxProcedureGroup", "taxFactorGroup", "taxCompetenceGroup"}


def _local_name(value: str | None) -> str | None:
    if value is None:
        return None
    if "}" in value:
        return value.split("}", 1)[1]
    if ":" in value:
        return value.split(":", 1)[1]
    return value


def _parse_occurs(element: ET.Element) -> dict:
    min_occurs = int(element.attrib.get("minOccurs", "1"))
    max_raw = element.attrib.get("maxOccurs", "1")
    max_occurs: int | str
    if max_raw == "unbounded":
        max_occurs = "unbounded"
    else:
        max_occurs = int(max_raw)
    return {"min": min_occurs, "max": max_occurs}


class SchemaExplorer:
    def __init__(self, schema_path: Path):
        self.schema_path = schema_path
        try:
            self.tree = ET.parse(schema_path)
            self.root = self.tree.getroot()
        except Exception as exc:
            raise RuntimeError(f"Failed to parse schema at {schema_path}: {exc}") from exc

        self.target_namespace = self.root.attrib.get("targetNamespace", "")
        self.schema_version = self.root.attrib.get("version", "")

        self.elements = {
            element.attrib["name"]: element
            for element in self.root.findall("xs:element", NS)
            if "name" in element.attrib
        }
        self.complex_types = {
            item.attrib["name"]: item
            for item in self.root.findall("xs:complexType", NS)
            if "name" in item.attrib
        }
        self.simple_types = {
            item.attrib["name"]: item
            for item in self.root.findall("xs:simpleType", NS)
            if "name" in item.attrib
        }
        self.attribute_groups = {
            item.attrib["name"]: item
            for item in self.root.findall("xs:attributeGroup", NS)
            if "name" in item.attrib
        }

    def get_summary(self) -> dict:
        root_elements = list(self.elements.keys())
        top_level_types = list(self.complex_types.keys())
        return {
            "schemaVersion": self.schema_version,
            "targetNamespace": self.target_namespace,
            "schemaLocation": f"schema/{SCHEMA_FILE}",
            "rootElements": root_elements,
            "topLevelTypes": top_level_types,
        }

    def get_tree(self) -> dict:
        root_name = self._find_root_element_name()
        if root_name is None:
            raise RuntimeError("Schema has no top-level root element.")
        root_element = self.elements[root_name]
        node = self._build_element_node(root_element, visited_types=set())
        return {"root": node}

    def _find_root_element_name(self) -> str | None:
        if "naturalPersonTaxData" in self.elements:
            return "naturalPersonTaxData"
        for name in self.elements:
            return name
        return None

    def _build_element_node(self, element: ET.Element, visited_types: set[str]) -> dict:
        element_name = element.attrib.get("name", "")
        type_name = _local_name(element.attrib.get("type"))

        node = {
            "name": element_name,
            "kind": "element",
            "type": type_name,
            "namespace": self.target_namespace,
            "cardinality": _parse_occurs(element),
            "attributes": [],
            "enumeration": None,
            "children": [],
        }

        inline_simple = element.find("xs:simpleType", NS)
        inline_complex = element.find("xs:complexType", NS)

        if inline_simple is not None:
            node["enumeration"] = self._extract_simple_type_enum(inline_simple)

        if inline_complex is not None:
            node["attributes"] = self._collect_complex_attributes(inline_complex)
            node["children"] = self._collect_child_elements(inline_complex, visited_types)
            return node

        if type_name in self.simple_types:
            node["enumeration"] = self._extract_simple_type_enum(self.simple_types[type_name])

        if type_name in self.complex_types:
            if type_name in visited_types:
                return node
            next_visited = set(visited_types)
            next_visited.add(type_name)
            complex_type = self.complex_types[type_name]
            node["attributes"] = self._collect_complex_attributes(complex_type)
            node["children"] = self._collect_child_elements(complex_type, next_visited)

        return node

    def _collect_child_elements(self, container: ET.Element, visited_types: set[str]) -> list[dict]:
        children: list[dict] = []
        for child in self._iter_elements_in_order(container):
            children.append(self._build_element_node(child, visited_types))
        return children

    def _iter_elements_in_order(self, container: ET.Element):
        for node in list(container):
            tag = _local_name(node.tag)
            if tag == "element":
                yield node
                continue
            if tag in {"sequence", "choice", "all"}:
                for inner in self._iter_elements_in_order(node):
                    yield inner
                continue
            if tag in {"complexContent", "simpleContent"}:
                for extension in node.findall("xs:extension", NS):
                    for inner in self._iter_elements_in_order(extension):
                        yield inner
                for restriction in node.findall("xs:restriction", NS):
                    for inner in self._iter_elements_in_order(restriction):
                        yield inner

    def _collect_complex_attributes(self, complex_node: ET.Element) -> list[dict]:
        attributes: list[dict] = []

        for attr in complex_node.findall("xs:attribute", NS):
            attributes.append(self._build_attribute(attr, source=None))

        for group_ref in complex_node.findall("xs:attributeGroup", NS):
            ref_name = _local_name(group_ref.attrib.get("ref"))
            if ref_name is None:
                continue
            attributes.extend(self._resolve_attribute_group(ref_name, seen_groups=set()))

        for extension in complex_node.findall(".//xs:extension", NS):
            for attr in extension.findall("xs:attribute", NS):
                attributes.append(self._build_attribute(attr, source=None))
            for group_ref in extension.findall("xs:attributeGroup", NS):
                ref_name = _local_name(group_ref.attrib.get("ref"))
                if ref_name is None:
                    continue
                attributes.extend(self._resolve_attribute_group(ref_name, seen_groups=set()))

        return attributes

    def _resolve_attribute_group(self, group_name: str, seen_groups: set[str]) -> list[dict]:
        if group_name in seen_groups:
            return []

        group = self.attribute_groups.get(group_name)
        if group is None:
            return []

        next_seen = set(seen_groups)
        next_seen.add(group_name)

        resolved: list[dict] = []
        for child in list(group):
            tag = _local_name(child.tag)
            if tag == "attribute":
                source = group_name if group_name in HIGHLIGHT_GROUPS else group_name
                resolved.append(self._build_attribute(child, source=source))
            elif tag == "attributeGroup":
                nested_name = _local_name(child.attrib.get("ref"))
                if nested_name:
                    resolved.extend(self._resolve_attribute_group(nested_name, next_seen))

        return resolved

    def _build_attribute(self, attr: ET.Element, source: str | None) -> dict:
        type_name = _local_name(attr.attrib.get("type"))

        enum_values: list[str] = []
        inline_simple = attr.find("xs:simpleType", NS)
        if inline_simple is not None:
            enum_values = self._extract_simple_type_enum(inline_simple)
        elif type_name and type_name in self.simple_types:
            enum_values = self._extract_simple_type_enum(self.simple_types[type_name])

        return {
            "name": attr.attrib.get("name", ""),
            "kind": "attribute",
            "type": type_name,
            "enum": enum_values,
            "source": source,
        }

    def _extract_simple_type_enum(self, simple_type_node: ET.Element) -> list[str]:
        values = []
        for enum_node in simple_type_node.findall(".//xs:enumeration", NS):
            value = enum_node.attrib.get("value")
            if value is not None:
                values.append(value)
        return values


EXPLORER = SchemaExplorer(SCHEMA_PATH)


def get_schema_summary() -> dict:
    return EXPLORER.get_summary()


def get_schema_tree() -> dict:
    return EXPLORER.get_tree()