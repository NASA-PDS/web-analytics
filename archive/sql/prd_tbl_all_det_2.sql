
/*
    Unfortunately, Athena can only have one statement per execution.
    Identify partition in S3 Directory structure
*/

ALTER TABLE pds_analytics.prd_tbl_all_det ADD
PARTITION (node='atm') location 's3://pds-web-analytics-cloud/logs/atm'
PARTITION (node='geo') location 's3://pds-web-analytics-cloud/logs/geo'
PARTITION (node='img') location 's3://pds-web-analytics-cloud/logs/img'
PARTITION (node='naif') location 's3://pds-web-analytics-cloud/logs/naif'
PARTITION (node='ppi') location 's3://pds-web-analytics-cloud/logs/ppi'
PARTITION (node='rings') location 's3://pds-web-analytics-cloud/logs/rings'
PARTITION (node='sbn') location 's3://pds-web-analytics-cloud/logs/sbn'
PARTITION (node='en') location 's3://pds-web-analytics-cloud/logs/en';
