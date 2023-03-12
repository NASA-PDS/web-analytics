#!/bin/bash

BASE_LOGDIR="/report_service/logs/final"

# Engineering
aws --profile saml-pub s3 sync ${BASE_LOGDIR}/en s3://pds-web-analytics-cloud/logs/en --exclude "*" --include "en-http-pdscloud*/*.txt.gz" 

# Imaging
aws --profile saml-pub s3 sync ${BASE_LOGDIR}/img s3://pds-web-analytics-cloud/logs/img --exclude "*" --include "img-pdsimg*"

