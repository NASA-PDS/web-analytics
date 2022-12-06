
/*
    Unfortunately, Athena can only have one statement per execution.
    Identify partition in S3 Directory structure
*/

ALTER TABLE pds_analytics.prd_tbl_all_det ADD
PARTITION (node='atm') location 's3://pds-web-analytics/atm'
PARTITION (node='geo') location 's3://pds-web-analytics/geo'
PARTITION (node='img') location 's3://pds-web-analytics/img'
PARTITION (node='naif') location 's3://pds-web-analytics/naif'
PARTITION (node='ppi') location 's3://pds-web-analytics/ppi'
PARTITION (node='rings') location 's3://pds-web-analytics/rings'
PARTITION (node='sbn') location 's3://pds-web-analytics/sbn'
PARTITION (node='en') location 's3://pds-web-analytics/en';