CREATE TABLE prd_tbl_en_search_qry AS
SELECT DATE(DATE_PARSE(SPLIT(datetime, ' ')[1], '[%d/%M/%Y:%H:%i:%s')) as date,
lower(regexp_replace(regexp_extract(client_request, 'GET \/datasearch\/keyword-search\/search.jsp\?q\=([\w\+\-\%]+)', 1), '(\+|(\%20))', ' ')) as query_text,
client_request, client_ip, datetime, status,
cast(replace(size, '-', '0') as bigint) as bytes,
referer, user_agent
from pds_analytics.prd_tbl_all_det
where 1=1
and node = 'en'
and client_request like '%GET /datasearch/keyword--search/search.jsp?q=%' ESCAPE '-'



