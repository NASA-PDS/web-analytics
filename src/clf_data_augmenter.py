"""
    Class and functions to mutate Apache CLF dataframes.

"""
import pandas as pd


class CLFDataAugmenter(object):

    def __init__(self, data: pd.DataFrame):
        self.df = data
        self.augmented = False


    def augment_data(self):
        """Data mutations and augmentations """

        self.df = self.df.astype({'status': int, 'size': int, 'hour': int}, errors='ignore')
        self.df['req_type'] = self.df['request'].str.split().str.get(0)
        self.df['date'] = pd.to_datetime(self.df['date'])
        self.df['month_year'] = pd.to_datetime(self.df['month_year'])

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
        self.augmented = True

    def get_df(self):
        print(f"Data augmented? {self.augmented}")
        return self.df
