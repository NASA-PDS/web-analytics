import os
import sys
import re
from time import process_time
from pathlib import Path
from multiprocessing import Pool

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
from apachelogs import LogParser

data_dir = Path('/Users/kaipak/datasets/pds/pds_logs/report_service/logs/final/img/img-pdsimage-http/')
column_names = ['ip', 'identd', 'userid', 'date', 'time', 'timezone', 'request', 'status', 'size', 'referer', 'user_agent']
log_files = [data_dir / f for f in os.listdir(data_dir)].sort()
df_logs = pd.DataFrame(columns=column_names)
parser = LogParser("%h %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-Agent}i\"")
df_http_logs = pd.DataFrame(columns=column_names)
log_files = sorted([data_dir / f for f in os.listdir(data_dir)])
log_files = log_files[:31] # Just deal with a month's worth for now.

def parse_line(line):
    """Parse a line from log and return a list with log entries in CLF order"""
    parsed = parser.parse(line)
    datetime = parsed.request_time
    parsed_line = [parsed.remote_host,
                   parsed.remote_logname,
                   parsed.remote_user,
                   datetime.date(),
                   datetime.time(),
                   datetime.tzinfo,
                   parsed.request_line,
                   parsed.final_status,
                   parsed.bytes_sent,
                   parsed.headers_in["Referer"],
                   parsed.headers_in["User-Agent"]
                  ]
    return parsed_line


def parse_file(file):
    log_file = open(file)
    lines = log_file.readlines()
    log_entries = list(map(parse_line, lines))
    df = pd.DataFrame(log_entries, columns=column_names)
    
    print(df.shape[0])
    return df

if __name__ == '__main__':
    with Pool(16) as p:
        print(p.map(parse_file, log_files))
