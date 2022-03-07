"""
    Class and functions to mutate Apache CLF dataframes.

"""
import pandas as pd


class CLFDataAugmenter(object):

    def __init__(self, data: pd.DataFrame):
        self.df = data
        self.df['req_type'] = self.df['request'].str.split().str.get(0)
        # Assume if I can't categorize the tool, it's just basic content.
        self.df['tool'] = "content"
        self.df.loc[(~self.df['log_name'].str.contains("tool", na=False)) &
                   (self.df['request'].str.contains('viewer|tracker|ephem')), 'tool'] = (
            self.df['request'].str.split(r'/').str.get(2).str.split('_').str.get(0)
        )
        self.df.loc[(~self.df['log_name'].str.contains("tool", na=False)) &
                   (self.df['request'].str.contains('\/galleries')), 'tool'] = "galleries"
        self.df.loc[(~self.df['log_name'].str.contains("tool", na=False)) &
                   (self.df['request'].str.contains('\/viewmaster')), 'tool'] = "viewmaster"
        self.df.loc[self.df['log_name'] == 'tools2', 'tool'] = 'opus'
        self.df.loc[self.df['log_name'] == 'tools', 'tool'] = 'opus'

    def get_df(self):
        return self.df