select *, SPLIT(client_request, ' ')[1] as req_type from pds_analytics.prd_tbl_all_det
where node = 'img' and
not regexp_like(SPLIT(client_request, ' ')[1], '[a-zA-Z]{3,}')
limit 100;


select http_method, count(*) from  pds_analytics.prd_vw_img_agg
group by 1;


select distinct date from  pds_analytics.prd_vw_img_agg;

select http_method, count(*)
from pds_analytics.tbl_test
group by 1;
