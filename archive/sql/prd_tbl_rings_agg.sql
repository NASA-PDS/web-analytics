CREATE TABLE prd_tbl_rings_agg AS
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
    AND node = 'rings'
GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9
ORDER BY 1
