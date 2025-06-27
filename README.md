# PDS Web Analytics

A comprehensive web analytics system for the Planetary Data System (PDS) that processes and analyzes web access logs from multiple PDS nodes using Logstash, OpenSearch, and AWS services.

## Overview

This system ingests web access logs from various PDS nodes (ATM, EN, GEO, IMG, NAIF, PPI, RINGS, SBN) and processes them through a Logstash pipeline to extract meaningful analytics data. The processed data is stored in OpenSearch for visualization and analysis.

### Key Features

- **Multi-format Log Processing**: Supports Apache Combined, IIS, FTP, and Tomcat log formats
- **ECS v8 Compliance**: All data is structured according to Elastic Common Schema v8
- **Comprehensive Error Handling**: Bad logs are tagged and stored separately for analysis
- **Geographic IP Resolution**: Automatic geolocation and reverse DNS lookup
- **User Agent Analysis**: Bot detection and user agent parsing
- **Test Framework**: Automated testing with sample log data
- **AWS Integration**: S3 log ingestion and OpenSearch output

## Architecture

```
PDS Nodes → S3 Bucket → Logstash Pipeline → OpenSearch → Dashboards
                ↓
            Error Logs → Bad Logs File
```

See internal wiki for more detailed architecture.

## Prerequisites

### System Requirements
- **Operating System**: Linux/Unix (tested on CentOS 7.9, macOS)
- **Python**: 3.9.x or higher
- **Java**: OpenJDK 11 or higher (required for Logstash)
- **Memory**: Minimum 4GB RAM (8GB+ recommended for production)
- **Storage**: 10GB+ available disk space

### AWS Resources


See internal wiki for more details.

### Required Software

#### 1. Anaconda/Conda
```bash
# Download and install Anaconda from https://www.anaconda.com/products/individual
# Or install Miniconda for a minimal installation
```

#### 2. AWS CLI
```bash
# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Configure AWS credentials
aws configure
```

#### 3. Logstash
```bash
# Download Logstash 8.x
wget https://artifacts.elastic.co/downloads/logstash/logstash-8.17.0-linux-x86_64.tar.gz
tar -xzf logstash-8.17.0-linux-x86_64.tar.gz
sudo mv logstash-8.17.0 /opt/logstash

# Add to PATH
echo 'export PATH="/opt/logstash/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# Verify installation
logstash --version
```

## Installation

### 1. Clone the Repository
```bash
git clone https://github.com/NASA-PDS/web-analytics.git
cd web-analytics
```

### 2. Set Up Python Environment
*TODO: We should update this to use Python venv. Conda is not the path forward.*
```bash
# Create and activate Conda environment
conda env create -f environment.yml
conda activate pds-analytics
```

### 3. Configure Environment Variables
Create a `.env` file in the repository root:
```bash
# AWS Configuration
export AWS_REGION=us-west-2
export S3_BUCKET_NAME=your-pds-logs-bucket
export AOSS_URL=https://your-opensearch-domain.us-west-2.es.amazonaws.com
export INDEX_PREFIX=pds-web-analytics

# Logstash Configuration
export LS_SETTINGS_DIR=$(pwd)/config/logstash/config
```
*See internal wiki for details of how to populate this file*

### 4. Set Up Logstash Configuration
```bash
# Source your config
source .env

# Make the build script executable
chmod +x scripts/logstash_build_config.sh

# Run the configuration build script
./scripts/logstash_build_config.sh
```

This script will:
- Copy the pipelines template and replace the env variables to `pipelines.yml`
- Create individual pipeline configuration files for each PDS node
- Combine input, filter, and output configurations automatically

## Package Structure

The PDS Web Analytics system is organized as a Python package:

```
src/pds/web_analytics/
├── __init__.py          # Package initialization
├── s3_sync.py          # S3Sync class implementation
└── VERSION.txt         # Package version
```

### Installing the Package

After setting up the environment, install the package in development mode:

```bash
# Install in development mode
pip install -e .

# Verify installation
s3-log-sync --help
```

This makes the `s3-log-sync` command available system-wide.

## Configuration

### Logstash Configuration Structure

```
config/logstash/config/
├── inputs/                    # S3 input configurations for each PDS node
│   ├── pds-input-s3-atm.conf
│   ├── pds-input-s3-en.conf
│   ├── pds-input-s3-geo.conf
│   ├── pds-input-s3-img.conf
│   ├── pds-input-s3-naif.conf
│   ├── pds-input-s3-ppi.conf
│   ├── pds-input-s3-rings.conf
│   └── pds-input-s3-sbn.conf
├── shared/                    # Shared filter and output configurations
│   ├── pds-filter.conf       # Main processing pipeline
│   └── pds-output-opensearch.conf
├── plugins/                   # Custom plugins and patterns
│   └── regexes.yaml
├── logstash.yml              # Logstash main configuration
└── pipelines.yml.template    # Pipeline definitions
```

### S3 Log Sync Configuration

Create a configuration file based on `config/config_example.yaml`:

```yaml
log_directory: /var/log/pds
profile_name: pds-analytics
s3_bucket: your-pds-logs-bucket
s3_logdir: logs
subdirs:
  atm:
    atm-apache-http:
      include:
        - "*.log"
    atm-atmos-ftp:
      include:
        - "*.log"
  en:
    en-http:
      include:
        - "*.log"
  # Add other nodes as needed
```

## Usage

### 1. S3 Log Synchronization

Sync logs from PDS reporting servers to S3:

```bash
# Using the new package command (recommended)
s3-log-sync -c config/config.yaml -d /var/log/pds --aws-profile pds-analytics

# Or using the legacy script wrapper
python scripts/s3_log_sync.py -c config/config.yaml -d /var/log/pds --aws-profile pds-analytics

# Disable gzip compression
s3-log-sync -c config/config.yaml -d /var/log/pds --aws-profile pds-analytics --no-gzip

# Set up as a cron job (example: every hour)
0 * * * * cd /path/to/web-analytics && s3-log-sync -c config/config.yaml -d /var/log/pds --aws-profile pds-analytics
```

### 2. Logstash Processing

Start Logstash with the PDS configuration:

```bash
# Set environment variables
export LS_SETTINGS_DIR=$(pwd)/config/logstash/config

# Start Logstash
logstash -f config/logstash/config/pipelines.yml --config.reload.automatic

# Or run with specific configuration
logstash -f config/logstash/config/inputs/pds-input-s3-en.conf \
         -f config/logstash/config/shared/pds-filter.conf \
         -f config/logstash/config/shared/pds-output-opensearch.conf
```

### 3. Testing

Run the comprehensive test suite:

```bash
# Make test script executable
chmod +x tests/run_tests.sh

# Run tests
./tests/run_tests.sh
```

The test suite validates:
- Log parsing accuracy
- Error handling
- Bad log detection
- ECS field mapping
- Output formatting

### 4. Monitoring

Check Logstash status and logs:

```bash
# Check Logstash process
ps aux | grep logstash

# View Logstash logs
tail -f /var/log/logstash/logstash.log

# Monitor bad logs
tail -f /tmp/bad_logs_$(date +%Y-%m).txt
```

## Data Processing

### Supported Log Formats

1. **Apache Combined Log Format**
   ```
   192.168.1.1 - - [25/Dec/2023:10:30:45 +0000] "GET /data/file.txt HTTP/1.1" 200 1024 "http://referrer.com" "Mozilla/5.0..."
   ```

2. **Microsoft IIS Log Format**
   ```
   2023-12-25 10:30:45 W3SVC1 192.168.1.1 GET /data/file.txt 80 - 192.168.1.100 Mozilla/5.0... 200 0 0 1024 0 15
   ```

3. **FTP Transfer Logs**
   ```
   Mon Dec 25 10:30:45 2023 1 192.168.1.1 1024 /data/file.txt a _ o r user ftp 0 * c
   ```

4. **Tomcat Access Logs**
   ```
   192.168.1.1 - - [25/Dec/2023:10:30:45 +0000] "GET /webapp/data HTTP/1.1" 200 1024
   ```

### ECS Field Mapping

The system maps log data to Elastic Common Schema v8 fields (among others):

- `[source][address]` - Client IP address
- `[url][path]` - Requested URL path
- `[http][request][method]` - HTTP method (GET, POST, etc.)
- `[http][response][status_code]` - HTTP status code
- `[http][response][body][bytes]` - Response size in bytes
- `[user_agent][original]` - User agent string
- `[event][start]` - Request timestamp
- `[organization][name]` - PDS node identifier

### Error Handling

The system handles various error conditions:

- **Bad Unicode**: Logs with invalid characters are tagged with `bad_log`
- **Parse Failures**: Unparseable logs are tagged with `_grok_parse_failure`
- **Invalid HTTP Methods**: Non-standard methods are tagged with `_invalid_http_method`
- **Missing Fields**: Logs missing required fields are tagged appropriately

All error logs are stored in `/tmp/bad_logs_YYYY-MM.txt` with detailed error information.

## PDS Node Support

The system processes logs from the following PDS nodes:

| Node | Domain | Protocol | Dataset |
|------|--------|----------|---------|
| ATM | pds-atmospheres.nmsu.edu | HTTP/FTP | atm.http, atm.ftp |
| EN | pds.nasa.gov | HTTP | en.http |
| GEO | Multiple domains | HTTP/FTP | geo.http, geo.ftp |
| IMG | pds-imaging.jpl.nasa.gov | HTTP | img.http |
| NAIF | naif.jpl.nasa.gov | HTTP/FTP | naif.http, naif.ftp |
| PPI | pds-ppi.igpp.ucla.edu | HTTP | ppi.http |
| RINGS | pds-rings.seti.org | HTTP | rings.http |
| SBN | Multiple domains | HTTP | sbn.http |

## Development

### Project Structure

```
web-analytics/
├── config/                    # Configuration files
│   ├── logstash/             # Logstash configurations
│   └── config_example.yaml   # S3 sync configuration template
├── scripts/                   # Utility scripts
│   ├── s3_log_sync.py        # S3 log synchronization
│   └── img_s3_download.py    # Image data download
├── tests/                     # Test framework
│   ├── data/logs/            # Sample log files
│   ├── config/               # Test configurations
│   └── run_tests.sh          # Test runner
├── docs/                      # Documentation
├── terraform/                 # Infrastructure as Code
└── src/                       # Source code
```

### Adding New PDS Nodes

1. Create a new input configuration in `config/logstash/config/inputs/`
2. Add the node to `config/logstash/config/pipelines.yml.template`
3. Update the S3 sync configuration
4. Add test cases to the test framework
5. Update this README with node information

### Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Run the test suite
6. Submit a pull request

## Troubleshooting

### Common Issues

1. **Logstash won't start**
   - Check Java installation: `java -version`
   - Verify configuration syntax: `logstash -t -f config_file.conf`
   - Check file permissions

2. **No data in OpenSearch**
   - Verify AWS credentials and permissions
   - Check S3 bucket access
   - Review Logstash logs for errors

3. **High memory usage**
   - Adjust `pipeline.batch.size` in `logstash.yml`
   - Reduce `pipeline.workers` if needed
   - Monitor system resources

4. **Parse failures**
   - Check log format matches expected patterns
   - Review bad logs file for specific issues
   - Update grok patterns if needed

### Log Locations

- **Logstash logs**: `/var/log/logstash/`
- **Bad logs**: `/tmp/bad_logs_YYYY-MM.txt`
- **Test output**: `target/test/`

### Performance Tuning

For production deployments:

1. **Instance sizing**: Use t3.xlarge or larger for high-volume processing
2. **Batch processing**: Adjust `pipeline.batch.size` based on memory availability
3. **Queue settings**: Configure `queue.max_bytes` and `queue.max_events`
4. **Monitoring**: Set up CloudWatch metrics for Logstash performance

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE.md](LICENSE.md) file for details.

## Support

For questions and support:
- Check the [PDS Web Analytics PDF](PDS%20Web%20Analytics%20with%20Logstash%20_97cf55c410a64bbc903a13347b02ea71-260625-0752-1596.pdf) for detailed technical information
- Review the test framework for usage examples
- Contact the PDS development team

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for a detailed history of changes and improvements.
