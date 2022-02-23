import numpy as np
import pandas as pd
import time
from apachelogs import LogParser

COLUMN_NAMES = ['ip', 'identd', 'userid', 'date', 'time', 'timezone',
                'request', 'status', 'size', 'referer', 'user_agent']
PARSER = LogParser("%h %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-Agent}i\"")


class CLFParse(object):
    """Parse Combined Log Format Apache log files into Pandas dataframes with option to output to other formats"""

    def __init__(self, logfiles: list[str]):
        self.logfiles = logfiles
        self.df_logs = pd.DataFrame(columns=COLUMN_NAMES)

    def parse_files(self):
        """"""
        print(f"Logfiles list contains {len(self.logfiles)} files.")
        tick = time.time()
        counter = 1
        for file in self.logfiles:
            if counter % 10 == 0:
                tock = time.time()
                curr_time = np.round((tock - tick) / 60, 2)
                print(f"{counter} files have been processed. {curr_time} minutes elapsed")
            log = open(file)
            lines = log.readlines()
            log_parsed = list(map(self._parse_line, lines))
            self.df_logs = pd.concat([self.df_logs, pd.DataFrame(log_parsed, columns=COLUMN_NAMES)])
            counter += 1
        elapsed = np.round((time.time() - tick) / 60, 2)
        print(f"{elapsed}m to process log files.")

    def _parse_line(self, line):
        """Process line from logfile"""
        parsed = PARSER.parse(line)
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