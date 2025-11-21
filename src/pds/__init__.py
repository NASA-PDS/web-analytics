# -*- coding: utf-8 -*-
"""PDS Namespace."""
# Use pkgutil for namespace packages (PEP 420 compatible, no external dependencies)
__path__ = __import__("pkgutil").extend_path(__path__, __name__)
