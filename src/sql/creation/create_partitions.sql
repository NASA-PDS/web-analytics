ALTER TABLE pds_analytics.tbl_pds_all_logs_raw ADD
PARTITION (node='atm') location 's3://pds-web-analytics/atm'
PARTITION (node='geo') location 's3://pds-web-analytics/img'
PARTITION (node='naif') location 's3://pds-web-analytics/naif'
PARTITION (node='ppi') location 's3://pds-web-analytics/ppi'
PARTITION (node='rings') location 's3://pds-web-analytics/rings'
PARTITION (node='sbn') location 's3://pds-web-analytics/sbn';
