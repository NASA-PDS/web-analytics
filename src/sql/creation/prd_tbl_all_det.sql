-- Create initial raw table from PDS node web logs.
CREATE EXTERNAL TABLE prd_tbl_all_det(
            client_ip string,
            client_id string,
            user_id string,
            datetime string,
            client_request string,
            status string,
            size string,
            referer string,
            user_agent string)
PARTITIONED BY (`node` string)
ROW FORMAT SERDE 'com.amazonaws.glue.serde.GrokSerDe'
WITH SERDEPROPERTIES ('input.format' = '^%{IPV4:client_ip}
                       %{DATA:client_id}
                       %{USERNAME:user_id}
                       %{GREEDYDATA:datetime}
                       %{QUOTEDSTRING:client_request}
                       %{DATA:status}
                       %{DATA: size}
                       %{QUOTEDSTRING:referer}
                       %{QUOTEDSTRING:user_agent}$')
STORED AS INPUTFORMAT 'org.apache.hadoop.mapred.TextInputFormat'
OUTPUTFORMAT 'org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat'
LOCATION 's3://pds-web-analytics/';