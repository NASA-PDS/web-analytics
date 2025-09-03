CREATE TABLE prd_tbl_naif_agg AS
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
    WHEN client_request like '%utilities%'
        AND CARDINALITY(split(client_request, '/')) > 1
        AND split(client_request, '/')[2] like '%pub%' THEN 'Data Server Area'
    WHEN client_request like '%chronos_msl.pl%' THEN 'Chronos MSL'
    WHEN client_request like '%cosmographia%' THEN 'Cosmographia'
    WHEN client_request like '%toolkit%' THEN 'Toolkit'
    WHEN CARDINALITY(split(client_request, '/')) > 2
        AND split(client_request, '/')[3] = 'naif'
        AND split(client_request, '/')[4] = 'utilities' THEN 'Utilities'
    WHEN CARDINALITY(split(client_request, '/')) > 2
        AND split(client_request, '/')[3] = 'naif'
        AND split(client_request, '/')[4] = 'misc' THEN 'Misc'
    WHEN client_request like '%data_archived.html%' THEN 'SPICE PDS Archive Subsetter'
    WHEN client_request like '%chronos%'
        AND CARDINALITY(split(client_request, '/')) > 1
        AND split(client_request, '/')[2] = 'cgi_bin' THEN 'Chronos Apps'
    WHEN client_request like '%spice_announce%' THEN 'SPICE Announce'
    WHEN client_request like '%spice_discussion%' THEN 'SPICE Discussion'
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
    AND node = 'naif'
GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9
ORDER BY 1