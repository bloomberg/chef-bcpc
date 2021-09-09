# -*- encoding: utf-8 -*-
# Copyright (c) 2021 Bloomberg LP
#
# Authors: Ajay Tikoo <atikoo@bloomberg.net>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
# implied.
# See the License for the specific language governing permissions and
# limitations under the License.

from oslo_config import cfg

nova_helper = cfg.OptGroup(
    name='nova_helper',
    title='Configuration Options for nova_helper module')

NOVA_HELPER_OPTS = [
    cfg.IntOpt(
        'instance_migration_timeout',
        default='120',
        min=120,
        help='Number of seconds to wait for migration to complete'),

    cfg.IntOpt(
        'instance_migration_poll_interval',
        default='1',
        min=1,
        help='Number of seconds to wait between migration status checks'),
]


def register_opts(conf):
    conf.register_group(nova_helper)
    conf.register_opts(NOVA_HELPER_OPTS, group=nova_helper)


def list_opts():
    return [('nova_helper', NOVA_HELPER_OPTS)]

