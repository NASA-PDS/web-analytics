select date_format(date_, '%m-%Y') as month_yr, user_type, sum(data_transmit_gb) as data_transmit_gb, 'atm' as node
from atm_summary_p_day
group by date_format(date_, '%m-%Y'), user_type
UNION
select date_format(date_, '%m-%Y') as month_yr, user_type, sum(data_transmit_gb) as data_transmit_gb, 'geo' as node
from geo_summary_p_day
group by date_format(date_, '%m-%Y'), user_type
UNION
select date_format(date_, '%m-%Y') as month_yr, user_type, sum(data_transmit_gb) as data_transmit_gb, 'img' as node
from img_summary_p_day
group by date_format(date_, '%m-%Y'),  user_type
UNION
select date_format(date_, '%m-%Y') as month_yr, user_type, sum(data_transmit_gb) as data_transmit_gb, 'naif' as node
from naif_summary_p_day
group by date_format(date_, '%m-%Y'),  user_type
UNION
select date_format(date_, '%m-%Y') as month_yr, user_type, sum(data_transmit_gb) as data_transmit_gb, 'ppi' as node
from ppi_summary_p_day
group by date_format(date_, '%m-%Y'),  user_type
UNION
select date_format(date_, '%m-%Y') as month_yr, user_type, sum(data_transmit_gb) as data_transmit_gb, 'rms' as node
from rms_summary_p_day
group by date_format(date_, '%m-%Y'),  user_type
UNION
select date_format(date_, '%m-%Y') as month_yr, user_type, sum(data_transmit_gb) as data_transmit_gb, 'sbn' as node
from sbn_summary_p_day
group by date_format(date_, '%m-%Y'),  user_type
order by node, month_yr, user_type