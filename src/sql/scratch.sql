select *, SPLIT(client_request, ' ')[1] as req_type from pds_analytics.prd_tbl_all_det
where node = 'img' and
not regexp_like(SPLIT(client_request, ' ')[1], '[a-zA-Z]{3,}')
limit 100;


select http_method, count(*) from  pds_analytics.prd_vw_img_agg
group by 1;


select distinct date from  pds_analytics.prd_vw_img_agg;

select http_method, sum()
from pds_analytics.tbl_test
group by 1;

select request_class, http_method, sum(bytes) / pow(2, 30), sum(transactions) from pds_analytics.tbl_test
group by 1, 2
order by 1, 2;


select * from pds_analytics.prd_tbl_rings_agg
where transactions > 1;

select count(*) from pds_analytics.prd_tbl_rings_agg

select * from pds_analytics.prd_tbl_rings_agg
where request_class <> 'archive'
limit 1000;


select request_class, http_method, status, sum(bytes) / pow(2, 30) as gigabytes, count(*) as requests
from pds_analytics.prd_tbl_rings_agg
group by 1, 2, 3