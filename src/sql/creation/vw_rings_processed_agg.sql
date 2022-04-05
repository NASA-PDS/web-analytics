CREATE VIEW
  vw_rings_processed AS
SELECT
    DATE(DATE_PARSE(SPLIT(datetime, ' ')[1], '[%d/%M/%Y:%H:%i:%s')) as date,
    node,
    --client_ip,
    SPLIT(client_request, ' ')[1] as req_type,
    --client_request,
    status,
    --user_agent,
    CASE regexp_like(user_agent, 'ahrefs|Barkrowler|Baiduspider|bingbot|CCBot|Cliqzbot|cs.daum\.net|DataForSeoBot|DomainCrawler|DuckDuckGo|Exabot|Googlebot|linkdexbot|magpi|-crawler|MauiBot|MJ12bot|MTRobot|msnbot|OpenLinkProfiler\.org|opensiteexplorer|pingdom|rogerbot|SemrushBot|SeznamBot|sogou\.com|tt-rss|Wotbox|YandexBot|YandexImages|ysearch\/slurp|BLEXBot|Flamingo_SearchEngine|okhttp|scalaj-http|UptimeRobot|YisouSpider|proximic\.com\/info\/spider/i')
        WHEN TRUE THEN 'robot'
        ELSE 'human'
    END as user_type,
    CASE 
    WHEN regexp_like(client_request, 'tools') AND regexp_like(client_request, 'viewer') THEN 'viewer'
    WHEN regexp_like(client_request, 'tools') AND regexp_like(client_request, 'tracker') THEN 'tracker'
    WHEN regexp_like(client_request, 'tools') AND regexp_like(client_request, 'ephem') THEN 'ephem'
    WHEN regexp_like(client_request, 'tools') AND regexp_like(client_request, 'galleries') THEN 'galleries'
    WHEN regexp_like(client_request, 'tools') AND regexp_like(client_request, 'viewmaster') THEN 'viewmaster'
    ELSE 'archive'
    END AS request_class,
    sum(cast(replace(size, '-', '0') as bigint)) as bytes,
    count(client_ip) as transactions
FROM "pds_analytics"."tbl_pds_all_logs_raw"
WHERE
    1 = 1
    AND CARDINALITY(SPLIT(size, ' ')) = 1
    AND node = 'rings'
GROUP BY 1, 2, 3, 4, 5, 6
ORDER BY
    date(DATE_PARSE(SPLIT(datetime, ' ')[1], '[%d/%M/%Y:%H:%i:%s'))
