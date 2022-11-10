CREATE TABLE prd_tbl_geo_agg AS
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
    WHEN split(client_request, '/')[2] = 'spectrallibrary' THEN 'Spectral Library'
    WHEN split(client_request, '/')[2] = 'speclib' THEN 'Spectral Library'
    WHEN regexp_like(client_request, 'crism')
        AND split(client_request, '/')[2] = 'mro' THEN 'CRISM Spectral Library'
    WHEN regexp_like(client_request, 'makelabels')
        AND split(client_request, '/')[2] = 'tools' THEN 'MakeLabels'
    WHEN regexp_like(client_request, 'lend')
        AND split(client_request, '/')[2] = 'lro' THEN 'LRO LEND Data Viewer'
    WHEN regexp_like(client_request, 'sharad')
        AND split(client_request, '/')[2] = 'mro' THEN 'MRO SHARAD Reader'
    WHEN regexp_like(client_request, 'crism')
        AND split(client_request, '/')[2] = 'mro' THEN 'CRISM Analysis Toolkit (CAT)'
    WHEN regexp_like(client_request, 'omega')
        AND split(client_request, '/')[2] = 'mex' THEN 'OMEGA Analysis Toolkit (OAT)'
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
    AND node = 'geo'
GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9
ORDER BY 1