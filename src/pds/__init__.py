# -*- coding: utf-8 -*-
"""PDS Namespace."""
# Use pkgutil for namespace packages (PEP 420 compatible, no external dependencies)
__path__ = __import__("pkgutil").extend_path(__path__, __name__)

# Setuptools requires declare_namespace() for namespace packages during build
# This is only needed during package installation, not at runtime
try:
    __import__("pkg_resources").declare_namespace(__name__)
except ImportError:
    # pkg_resources not available at runtime - that's fine, pkgutil handles it
    pass
