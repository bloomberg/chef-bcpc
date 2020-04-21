#!/usr/bin/env python3

# Copyright 2020, Bloomberg Finance L.P.
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

import argparse
import sys
import yaml
from builtins import FileExistsError
from lib.bcc_chef_databags import BCCChefDatabags

if __name__ == '__main__':
    desc = "BCC Chef Databag Generator"
    parser = argparse.ArgumentParser(description=desc)

    parser.add_argument(
        "-s", "--save",
        default=False,
        action="store_true",
        help="save databag to file",
    )

    parser.add_argument(
        "-f", "--force",
        default=False,
        action="store_true",
        help="force databag overwrite if one already exists",
    )

    args = parser.parse_args()
    bccdb = BCCChefDatabags()

    if args.save:
        try:
            bccdb.save(force=args.force)
            sys.exit(0)
        except FileExistsError as e:
            print(e)
            sys.exit(1)

    print(yaml.dump(bccdb.generate(), default_flow_style=False, indent=2))
