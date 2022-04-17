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


select request_type, sum(bytes) / pow(2, 30) as gigabytes, sum(transactions) as requests
from pds_analytics.prd_tbl_rings_agg
group by 1

select * from pds_analytics.prd_tbl_rings_agg
where regexp_like(client_request, 'opus') and split(client_request, '/')[2] = 'opus'
limit 1000;

select sum(bytes) / pow(2, 20), sum(transactions) from pds_analytics.prd_tbl_rings_agg
where 1 = 1
and regexp_like(client_request, 'galleries')
and split(client_request, '/')[2] = 'galleries';


select CASE
    WHEN regexp_like(client_request, 'viewer3')
        AND split(client_request, '/')[2] = 'tools' THEN 'planet viewer'
    WHEN regexp_like(client_request, 'tracker2')
        AND split(client_request, '/')[2] = 'tools' THEN 'moon tracker'
    WHEN regexp_like(client_request, 'ephem')
        AND split(client_request, '/')[2] = 'tools' THEN 'ephemeris'
    WHEN regexp_like(client_request, 'galleries')
        AND split(client_request, '/')[2] = 'galleries' THEN 'galleries'
    WHEN regexp_like(client_request, 'viewmaster')
        AND split(client_request, '/')[2] = 'viewmaster' THEN 'viewmaster'
    WHEN regexp_like(client_request, 'opus')
        AND split(client_request, '/')[2] = 'opus' THEN 'opus'
    ELSE 'archive'
    END AS request_class,
    sum(bytes),
    sum(transactions)
from pds_analytics.prd_tbl_rings_agg
group by 1
--limit 500

/*
  Imaging EDA
 */

select request_type, http_method, sum(bytes), sum(transactions)
from pds_analytics.prd_tbl_img_agg
group by 1, 2;


/*
  Geo exploration
*/
select request_type, sum(bytes) / pow(2, 20), sum(transactions), count(*)
from pds_analytics.prd_tbl_geo_agg
group by 1

select *
from pds_analytics.prd_tbl_geo_agg
limit 1000;


select split(client_request, '/')[1], split(client_request, '/')[2], * from pds_analytics.prd_tbl_all_det
where node = 'atm'
limit 1000;
-- and cardinality(split(client_request, '/')) <= 1


/*
 NAIF
 */

select *
from pds_analytics.prd_tbl_all_det
where node = 'naif'
and client_request like '%utilities%'
limit 500;




















select date, node, request_type, user_type, http_method, status,
  sum(bytes) as bytes, count(transactions) as transactions
from pds_analytics.prd_tbl_geo_agg
group by date, node, request_type, user_type, http_method, status
UNION ALL
select date, node, request_type, user_type, http_method, status,
  sum(bytes) as bytes, count(transactions) as transactions
from pds_analytics.prd_tbl_img_agg
group by date, node, request_type, user_type, http_method, status
order by node, date, user_type, request_type, user_type, status