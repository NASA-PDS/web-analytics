PDS Web Analytics
==================

A comprehensive web analytics system for the Planetary Data System (PDS) that processes and analyzes web access logs from multiple PDS nodes using Logstash, OpenSearch, and AWS services.

Overview
========

This system ingests web access logs from various PDS nodes (ATM, EN, GEO, IMG, NAIF, PPI, RINGS, SBN) and processes them through a Logstash pipeline to extract meaningful analytics data. The processed data is stored in OpenSearch for visualization and analysis.

Key Features
------------

* **Multi-format Log Processing**: Supports Apache Combined, IIS, FTP, and Tomcat log formats
* **ECS v8 Compliance**: All data is structured according to Elastic Common Schema v8
* **Comprehensive Error Handling**: Bad logs are tagged and stored separately for analysis
* **Geographic IP Resolution**: Automatic geolocation and reverse DNS lookup
* **User Agent Analysis**: Bot detection and user agent parsing
* **Test Framework**: Automated testing with sample log data
* **AWS Integration**: S3 log ingestion and OpenSearch output
* **Environment Variable Support**: Configuration via environment variables with envsubst
* **Flexible AWS Profile**: Support for AWS_PROFILE environment variable
* **Native boto3 S3 Uploads**: S3 log sync now uses boto3 (no AWS CLI required for S3 uploads)

Architecture
------------

.. code-block:: text

    PDS Nodes → S3 Bucket → Logstash Pipeline → OpenSearch → Dashboards
                    ↓
                Error Logs → Bad Logs File

Table of Contents
=================

..  toctree::
    :maxdepth: 2
    :caption: Getting Started

    /installation/installation
    /usage/configuration
    /usage/usage

..  toctree::
    :maxdepth: 2
    :caption: Support

    /support/help
    /support/contribute
    /support/contact

Indices and tables
==================

* :ref:`genindex`
* :ref:`search`
