#!/bin/bash
# This script should really not be run as is. Just collection of commands run to sync weblogs with S3. Set to dry run so# it outputs files that would be sync'd but doesn't actually copy data.
# 

# 2021 and 2022
# Rings
aws --profile saml-pub s3 sync ./rings s3://pds-web-analytics/rings --exclude "*" --include "*2021*" --include "*2022*" --exclude "*.gz"

# Atmos
aws --profile saml-pub s3 sync atm/ s3://pds-web-analytics/atm --exclude '*' --include '*202*' --include '*201*' --exclude '*ncftpd*' --dryrun

# Imaging
aws --profile saml-pub s3 sync img/ s3://pds-web-analytics/img --exclude '*' --include '*2021*.log' --include '*2022*.log' --include '*log.2021*' --include '*log.2022*' --dryrun

