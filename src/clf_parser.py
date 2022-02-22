import pandas as pd
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
        for file in self.logfiles:
            log = open(file)
            lines = log.readlines()
            log_parsed = list(map(self._parse_line, lines))
            self.df_logs = pd.concat([self.df_logs, pd.DataFrame(log_parsed, columns=COLUMN_NAMES)])

    def _parse_line(self, line):
        """Process line from logfile"""
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