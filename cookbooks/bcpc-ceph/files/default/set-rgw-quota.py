#!/usr/bin/env python

import sys
import subprocess
import yaml

config_file = '/usr/local/etc/rgw-quota.yml'
list_user_cmd = ['radosgw-admin', 'metadata', 'list', 'user']

config = yaml.load(open(config_file))
process = subprocess.Popen(list_user_cmd, stdout=subprocess.PIPE)
stdout = process.communicate()[0].split()
for item in stdout:
    if item.startswith('"'):
        user = ''.join(c for c in item if c.isalnum())
        subprocess.call(['radosgw-admin', 'quota', 'enable', '--quota-scope=user', '--uid=' + user])
        if user in config['user']:
            # Set predefined user quota
            subprocess.call(['radosgw-admin', 'quota', 'set', '--quota-scope=user', '--uid=' + user, '--max-size=' + config['user'][user]['max_size'].__str__()])
        else:
            # Set default quota
            subprocess.call(['radosgw-admin', 'quota', 'set', '--quota-scope=user', '--uid=' + user, '--max-size=' + config['user']['default']['max_size'].__str__()])
