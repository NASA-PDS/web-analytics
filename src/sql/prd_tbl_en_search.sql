CREATE TABLE prd_tbl_en_search AS
SELECT DATE(DATE_PARSE(SPLIT(datetime, ' ')[1], '[%d/%M/%Y:%H:%i:%s')) as date,
lower(regexp_replace(regexp_extract(client_request, 'GET \/datasearch\/keyword-search\/search.jsp\?q\=([\w\+\-\%]+)', 1), '(\+|(\%20))', ' ')) as query_text,
client_request, client_ip, datetime, status,
cast(replace(size, '-', '0') as bigint) as bytes,
referer, user_agent
from pds_analytics.prd_tbl_all_det
where 1=1
and node = 'en'
and client_request like '%GET /datasearch/keyword--search/search.jsp?q=%' ESCAPE '-'
and SPLIT(datetime, ' ')[1] <> '-'



<script type="text/javascript" async="" src="https://www.google.com/cse/cse.js?cx=007870209983431604483:hux2hfzwefc"></script>
