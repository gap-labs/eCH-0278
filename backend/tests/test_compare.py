import sys
import unittest
from pathlib import Path


BACKEND_DIR = Path(__file__).resolve().parents[1]
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from app.comparison import compare_xml


class CompareXmlTests(unittest.TestCase):
    def test_leaf_value_and_node_count_diff(self):
        xml1 = b"""<root><a>1</a><b>2</b></root>"""
        xml2 = b"""<root><a>9</a><c>3</c></root>"""

        result = compare_xml(xml1, xml2)

        self.assertFalse(result["xml1Valid"])
        self.assertFalse(result["xml2Valid"])
        self.assertEqual(
            result["diffSummary"],
            {
                "changedValues": 1,
                "addedNodes": 1,
                "removedNodes": 1,
            },
        )

    def test_parse_error_returns_zero_diff(self):
        xml1 = b"""<root><a>1</a></root>"""
        xml2 = b"""<root><a>1</a>"""

        result = compare_xml(xml1, xml2)

        self.assertFalse(result["xml1Valid"])
        self.assertFalse(result["xml2Valid"])
        self.assertEqual(
            result["diffSummary"],
            {
                "changedValues": 0,
                "addedNodes": 0,
                "removedNodes": 0,
            },
        )


if __name__ == "__main__":
    unittest.main()
