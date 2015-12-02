
"""
This is a modified copy of https://github.com/python-diamond/Diamond/pull/105
which is pending fix/merge.
"""

try:
    import json
except ImportError:
    import simplejson as json

import subprocess
import re
import os
import sys
import diamond.collector

"""
Get usage statistics from the ceph cluster.
Total as well as per pool.
"""

class CephPoolStatsCollector(diamond.collector.Collector):

    labels = {
        'rd_bytes': 'read_bytes',
        'wr_bytes': 'written_bytes',
        'bytes_used': 'used_bytes',
        'objects': 'objects'
    }

    def collect(self):

        try:
            output = subprocess.check_output([
                'ceph',
                'df',
                'detail',
                '--format=json'
            ])
        except subprocess.CalledProcessError, err:
            self.log.info('Could not get stats: %s' % err)
            self.log.exception('Could not get stats')
            return False

        try:
            jsonData = json.loads(output)
        except Exception, err:
            self.log.info('Could not parse stats from ceph df: %s', err)
            self.log.exception('Could not parse stats from ceph df')
            return False

        stats = jsonData["stats"]

        for s in ['total_bytes', 'total_used_bytes', 'total_objects']:
            self.publish(s, stats[s], metric_type='GAUGE')

        pools = jsonData["pools"]

        for p in pools:
            metric = 'pool.' + p["name"]

            for s in p["stats"]:
                if s in ['bytes_used', 'objects']:
                    self.publish(
                        metric + '.' + self.labels[s],
                        p["stats"][s],
                        metric_type='GAUGE'
                    )

                if s in ['rd_bytes', 'wr_bytes']:
                    self.publish(
                        metric + '.' + self.labels[s],
                        p["stats"][s],
                        metric_type='COUNTER'
                    )

        return True
