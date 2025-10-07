CREATE TABLE prd_tbl_ppi_agg AS
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
    /*
    WHEN lower(client_request) like '%labeler%'
        AND split(client_request, '/')[2] = 'software' THEN 'Labeler'
    WHEN lower(client_request) like '%splash%'
        AND split(client_request, '/')[2] = 'software' THEN 'Splash'
    WHEN cardinality(split(client_request, '/')) > 2
        AND split(client_request, '/')[3] = 'index'
        AND split(client_request, '/')[2] = 'software' THEN 'Index Generator'
    WHEN lower(client_request) like '%cassiniffhscan%'
        AND split(client_request, '/')[2] = 'software' THEN 'CassiniFFHScan'
    WHEN lower(client_request) like '%compare%'
        AND split(client_request, '/')[2] = 'software' THEN 'Compare'
    WHEN lower(client_request) like '%formatdescription%'
        AND split(client_request, '/')[2] = 'software' THEN 'FormatDescription'
    WHEN lower(client_request) like '%imath%'
        AND split(client_request, '/')[2] = 'software' THEN 'IMath'
    WHEN lower(client_request) like '%labelvalue%'
        AND split(client_request, '/')[2] = 'software' THEN 'LabelValue'
    WHEN lower(client_request) like '%lookup%'
        AND split(client_request, '/')[2] = 'software' THEN 'Lookup'
    */
    WHEN cardinality(split(client_request, '/')) > 1
        AND split(client_request, '/')[2] = 'software' THEN 'PDS3 Software Pkgs'
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
    AND node = 'ppi'
GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9
ORDER BY 1
