CREATE TABLE prd_tbl_sbn_agg AS
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
    WHEN lower(client_request) like '%cxid%' THEN 'Comet Cross-Identification'
    WHEN lower(client_request) like '%readpds%' THEN 'ReadPDS'
    WHEN lower(client_request) like '%pds-ceres%' THEN 'Dawn Mission to Ceres'
    WHEN lower(client_request) like '%pds-vesta%' THEN 'Dawn Mission to Vesta'
    WHEN lower(client_request) like '%pds-eros%' THEN 'NEAR Shoemaker Mission to 433 Eros'
    WHEN lower(client_request) like '%saturn.html%' THEN 'Cassini Mission: Saturn Small Satellites'
    WHEN lower(client_request) like '%pds-mimas%' THEN 'Cassini Mission: Mimas (Saturn I)'
    WHEN lower(client_request) like '%pds-enceladus%' THEN 'Cassini Mission: Enceladus (Saturn II)'
    WHEN lower(client_request) like '%pds-tethys%' THEN 'Cassini Mission: Tethys (Saturn III)'
    WHEN lower(client_request) like '%pds-dione%' THEN 'Cassini Mission: Dione (Saturn IV)'
    WHEN lower(client_request) like '%pds-rhea%' THEN 'Cassini Mission: Tethys (Saturn V)'
    WHEN lower(client_request) like '%pds-lapetus%' THEN 'Cassini Mission: Tethys (Saturn VIII)'
    WHEN lower(client_request) like '%pds-phoebe%' THEN 'Cassini Mission: Phoebe (Saturn IX)'
    WHEN cardinality(split(client_request, '/')) > 1
        AND split(client_request, '/')[2] = 'wiki' THEN 'Wiki'
    WHEN cardinality(split(client_request, '/')) > 1
        AND split(client_request, '/')[2] = 'tools' THEN 'SBN Tools, Utilities, and Interfaces'
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
    AND node = 'sbn'
GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9
ORDER BY 1