/*
    Produce daily summarized view of all PDS logs

    date | node | client_ip | req_type | status | user_agent | user_type | filepath | data_transmit_gb | req_count
*/
CREATE OR REPLACE VIEW
  view_pds_all_processed AS
SELECT
    DATE(DATE_PARSE(SPLIT(datetime, ' ')[1], '[%d/%M/%Y:%H:%i:%s')) as date,
    datetime,
    SPLIT(SUBSTR("$path", 6), '/')[2] as node,
    client_ip,
    SPLIT(client_request, ' ')[1] as req_type,
    client_request,
    status,
    user_agent,
    CASE regexp_like(user_agent, 'ahrefs|Barkrowler|Baiduspider|bingbot|CCBot|Cliqzbot|cs.daum\.net|DataForSeoBot|DomainCrawler|DuckDuckGo|Exabot|Googlebot|linkdexbot|magpi|-crawler|MauiBot|MJ12bot|MTRobot|msnbot|OpenLinkProfiler\.org|opensiteexplorer|pingdom|rogerbot|SemrushBot|SeznamBot|sogou\.com|tt-rss|Wotbox|YandexBot|YandexImages|ysearch\/slurp|BLEXBot|Flamingo_SearchEngine|okhttp|scalaj-http|UptimeRobot|YisouSpider|proximic\.com\/info\/spider/i')
        WHEN TRUE THEN 'robot'
        ELSE 'human'
    END as user_type,
    "$path" as filepath,
    cast(replace(size, '-', '0') as bigint) as bytes
FROM "pds_analytics"."pds_all_logs_raw"
WHERE
    1 = 1
    AND CARDINALITY(SPLIT(size, ' ')) = 1
ORDER BY
    date(DATE_PARSE(SPLIT(datetime, ' ')[1], '[%d/%M/%Y:%H:%i:%s'))
