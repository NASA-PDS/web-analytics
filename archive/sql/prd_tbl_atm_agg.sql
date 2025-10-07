CREATE TABLE prd_tbl_atm_agg AS
SELECT
    DATE(DATE_PARSE(SPLIT(datetime, ' ')[1], '[%d/%M/%Y:%H:%i:%s')) as date,
    node,
    CASE WHEN SPLIT(client_request, ' ')[1] IN ('GET', 'HEAD', 'POST', 'PUT',
                                                'DELETE', 'CONNECT', 'OPTIONS',
                                                'TRACE', 'PATCH')
         THEN SPLIT(client_request, ' ')[1]
         ELSE 'UNK'
    END as http_method,
    status,
    CASE regexp_like(user_agent, 'ahrefs|Barkrowler|Baiduspider|bingbot|CCBot|Cliqzbot|cs.daum\.net|DataForSeoBot|DomainCrawler|DuckDuckGo|Exabot|Googlebot|linkdexbot|magpi|-crawler|MauiBot|MJ12bot|MTRobot|msnbot|OpenLinkProfiler\.org|opensiteexplorer|pingdom|rogerbot|SemrushBot|SeznamBot|sogou\.com|tt-rss|Wotbox|YandexBot|YandexImages|ysearch\/slurp|BLEXBot|Flamingo_SearchEngine|okhttp|scalaj-http|UptimeRobot|YisouSpider|proximic\.com\/info\/spider/i')
        WHEN TRUE THEN 'robot'
        ELSE 'human'
    END as user_type,
    CASE
    WHEN regexp_like(client_request, 'atmospheres_data') THEN 'PDS ATM Data Set Catalog'
    WHEN regexp_like(client_request, 'epic')
        AND CARDINALITY(split(client_request, '/')) > 1
        AND split(client_request, '/')[2] = 'data_and_services' THEN 'EPIC'
    WHEN regexp_like(client_request, 'mogc_0001') THEN 'Mars GCM'
    WHEN regexp_like(client_request, 'OAL') THEN 'Object Access Library'
    WHEN regexp_like(client_request, 'nasa_abstracts') THEN 'NASA Abstracts'
    WHEN regexp_like(client_request, 'LADEE')
        AND regexp_like(client_request, 'uvs') THEN 'LADEE UVS'
    WHEN regexp_like(client_request, 'LADEE')
        AND regexp_like(client_request, 'nms') THEN 'LADEE NMS'
    WHEN regexp_like(client_request, 'MAVEN')
        AND regexp_like(client_request, 'acc') THEN 'MAVEN ACC'
    WHEN regexp_like(client_request, 'MAVEN')
        AND regexp_like(client_request, 'ngims') THEN 'MAVEN NGIMS'
    WHEN regexp_like(client_request, 'VENUS-EXPRESS') THEN ' Venus Express'
    WHEN regexp_like(client_request, 'Cassini')
        AND CARDINALITY(split(client_request, '/')) > 1
        AND split(client_request, '/')[2] = 'data_and_services' THEN 'Cassini Data and Resources'
    ELSE 'archive'
    END AS request_type,
    client_request,
    user_agent,
    client_ip,
    sum(cast(replace(size, '-', '0') as bigint)) as bytes,
    count(client_ip) as transactions
FROM "pds_analytics"."prd_tbl_all_det"
WHERE
    1 = 1
    AND CARDINALITY(SPLIT(size, ' ')) = 1
    AND node = 'atm'
GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9
ORDER BY 1
