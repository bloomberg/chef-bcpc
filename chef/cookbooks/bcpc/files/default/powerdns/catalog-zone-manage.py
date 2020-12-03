#!/usr/bin/env python

# Copyright 2019, Bloomberg Finance L.P.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

# http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import sys
import time
import hashlib
import dns.name
import argparse
import configparser
from jinja2 import Template
from subprocess import call, check_output

config = configparser.ConfigParser()
config.read('/usr/local/etc/catalog-zone/catalog-zone.conf')


def nzfsum(zone):
    dns_name = dns.name.from_text(zone)
    return hashlib.sha1(dns_name.to_wire()).hexdigest()


def synchronize_catalog_zone():
    # use pdnsutil list-all-zones command to get all the zones
    # and then convert that list into an array
    all_zones = check_output('/usr/bin/pdnsutil list-all-zones'.split(' '))
    all_zones = all_zones.split()

    # loop over the array of zones and turn it into an array of hashes that
    # include the zone name and its nzf (new zone file) hash sum
    zones = []
    catalog_zone = config.get('DEFAULT', 'zone')
    for zone in all_zones:
        # don't include the catalog zone in the list of zones to be included
        # in the catalog zone
        if zone == catalog_zone:
            continue
        zones.append({'zone': zone, 'nzfsum': nzfsum(zone)})

    # parse the jinja2 zone template
    catalog_zone_tmpl = config.get('DEFAULT', 'zone_template')
    with open(catalog_zone_tmpl) as tmpl:
        template = Template(tmpl.read())

    # render the zone file
    serial = int(time.time())
    catalog_zone_file = config.get('DEFAULT', 'zone_file')
    with open(catalog_zone_file, 'w') as f:
        f.write(template.render(zone=catalog_zone, zones=zones, serial=serial))

    # load the zone file using pdnsutil
    load_zone = "/usr/bin/pdnsutil load-zone {zone} {zone_file}"
    load_zone = load_zone.format(zone=catalog_zone,
                                 zone_file=catalog_zone_file)
    call(load_zone.split(' '))


def main():
    parser = argparse.ArgumentParser(description="Manage the DNS Catalog Zone")

    parser.add_argument(
        "--sync",
        action='store_true',
        help="synchronize catalog zone"
    )

    args = parser.parse_args()

    if len(sys.argv) <= 1:
        parser.print_usage()
        sys.exit(1)

    if args.sync:
        try:
            synchronize_catalog_zone()
            sys.exit(0)
        except Exception as e:
            print(e)
            sys.exit(1)


if __name__ == "__main__":
    main()
