import logging
import multiprocessing

import numpy as np
import pandas as pd
import time
import tqdm
from apachelogs import LogParser
from multiprocessing import Pool
from datetime import datetime

COLUMN_NAMES = ["ip", "identd", "userid", "datetime", "request", "status", "size", "referer", "user_agent"]
PARSER = LogParser('%h %l %u %t "%r" %>s %b "%{Referer}i" "%{User-Agent}i"')


def parse_line(line):
    """Process line from logfile"""
    try:
        parsed = PARSER.parse(line)
        datetime = parsed.request_time
        parsed_line = [
            parsed.remote_host,
            parsed.remote_logname,
            parsed.remote_user,
            datetime,
            parsed.request_line,
            parsed.final_status,
            parsed.bytes_sent,
            parsed.headers_in["Referer"],
            parsed.headers_in["User-Agent"],
        ]
    except Exception as e:
        print(f"Error parsing {line}.")
        # self.logger.exception(f"Exception occurred when attempting to parse log file")
        parsed_line = [None] * 9
    return parsed_line


def proc_file(file):
    log = open(file)
    lines = log.readlines()
    log_parsed = list(map(parse_line, lines))
    return log_parsed


class CLFParse(object):
    """Parse Combined Log Format Apache log files into Pandas dataframes with option to output to other formats"""

    def __init__(self, logfiles: list[str]):
        self.logfiles = logfiles
        self.df_logs = pd.DataFrame(columns=COLUMN_NAMES)
        self.logger = logging.getLogger(__name__)
        self.c_handler = logging.StreamHandler()
        self.c_handler.setLevel(logging.INFO)
        self.c_format = logging.Formatter("%(name)s - %(levelname)s - %(message)s")
        self.c_handler.setFormatter(self.c_format)
        self.logger.addHandler(self.c_handler)

    def parse_files(self):
        """Take list of CLF log files and produce dataframe"""
        print(f"Logfiles list contains {len(self.logfiles)} files.")
        tick = time.time()

        pool = Pool(processes=multiprocessing.cpu_count())
        results = [pool.apply_async(proc_file, args=[f]) for f in self.logfiles]
        pool.close()
        pool.join()
        results_pandas = []
        for res in tqdm.tqdm(results):
            results_pandas.append(pd.DataFrame(res.get(), columns=COLUMN_NAMES))

        self.df_logs = pd.concat(results_pandas)
        self.df_logs["datetime"] = pd.to_datetime(self.df_logs["datetime"], utc=True)
        print(f"Expanding datetime field...")
        self._datetime_expand()
        elapsed = np.round((time.time() - tick) / 60, 2)
        print(f"{elapsed}m to process log files.")

    def to_file(self, type: str = "feather", filepath: str = "foo.feather"):
        """Write dataframe to some file format"""
        if self.df_logs.shape[0] == 0:
            print(f"Warning, this looks like an empty dataframe.")
        if type == "feather":
            self.df_logs.reset_index(drop=True).to_feather(filepath)
            print(f"Completed creating feather file at {filepath}.")
        elif type == "parquet":
            self.df_logs.reset_index(drop=True).to_parquet(filepath)
            print(f"Completed creating parquet file at {filepath}.")
        elif type == "csv":
            self.df_logs.reset_index(drop=True).to_csv(filepath)
            print(f"Completed creating csv file at {filepath}.")

    def _parse_line(self, line):
        """Process line from logfile"""
        try:
            parsed = PARSER.parse(line)
            datetime = parsed.request_time
            parsed_line = [
                parsed.remote_host,
                parsed.remote_logname,
                parsed.remote_user,
                datetime,
                parsed.request_line,
                parsed.final_status,
                parsed.bytes_sent,
                parsed.headers_in["Referer"],
                parsed.headers_in["User-Agent"],
            ]
        except Exception as e:
            print(f"Error parsing {line}.")
            self.logger.exception(f"Exception occurred when attempting to parse log file")
            parsed_line = [None] * 9
        return parsed_line

    def _datetime_expand(self):
        """Create columns of datetime attributes"""
        self.df_logs["date"] = self.df_logs["datetime"].dt.date
        self.df_logs["month_year"] = self.df_logs["datetime"].dt.strftime("%m-%Y")
        self.df_logs["DOW"] = self.df_logs["datetime"].dt.day_name()
        self.df_logs["hour"] = self.df_logs["datetime"].dt.hour
