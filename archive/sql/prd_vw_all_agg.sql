CREATE OR REPLACE VIEW
    prd_vw_all_agg AS
SELECT date, node, client_ip, request_type, user_type, http_method, status,
  sum(bytes) as bytes, count(transactions) as transactions
FROM pds_analytics.prd_tbl_atm_agg
GROUP BY date, node, client_ip, request_type, user_type, http_method, status
UNION ALL
SELECT date, node, client_ip, request_type, user_type, http_method, status,
  sum(bytes) as bytes, count(transactions) as transactions
FROM pds_analytics.prd_tbl_geo_agg
GROUP BY date, node, client_ip, request_type, user_type, http_method, status
UNION ALL
SELECT date, node, client_ip, request_type, user_type, http_method, status,
  sum(bytes) as bytes, count(transactions) as transactions
FROM pds_analytics.prd_tbl_img_agg
GROUP BY date, node, client_ip, request_type, user_type, http_method, status
UNION ALL
SELECT date, node, client_ip, request_type, user_type, http_method, status,
  sum(bytes) as bytes, count(transactions) as transactions
FROM pds_analytics.prd_tbl_rings_agg
GROUP BY date, node, client_ip, request_type, user_type, http_method, status
UNION ALL
SELECT date, node, client_ip, request_type, user_type, http_method, status,
  sum(bytes) as bytes, count(transactions) as transactions
FROM pds_analytics.prd_tbl_naif_agg
GROUP BY date, node, client_ip, request_type, user_type, http_method, status
UNION ALL
SELECT date, node, client_ip, request_type, user_type, http_method, status,
  sum(bytes) as bytes, count(transactions) as transactions
FROM pds_analytics.prd_tbl_ppi_agg
GROUP BY date, node, client_ip, request_type, user_type, http_method, status
UNION ALL
SELECT date, node, client_ip, request_type, user_type, http_method, status,
  sum(bytes) as bytes, count(transactions) as transactions
FROM pds_analytics.prd_tbl_sbn_agg
GROUP BY date, node, client_ip, request_type, user_type, http_method, status
ORDER BY node, date, user_type, request_type, user_type, status