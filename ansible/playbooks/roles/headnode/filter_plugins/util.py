"""
Copyright 2022, Bloomberg Finance L.P.
Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at
http://www.apache.org/licenses/LICENSE-2.0
Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
"""


class FilterModule(object):

    def filters(self):
        return {
            'host_traits': self.get_host_traits,
            'aggregates_to_add_host': self.get_aggregates_to_add_host,
            'aggregates_to_remove_host': self.get_aggregates_to_remove_host
        }

    def get_host_traits(self, host, license_traits):
        """Get traits for each host with specified licenses.

        Parameters:
        host (dict): dict of host information in inventory
        license_traits (dict): dict of licenses' key and traits' value

        Returns:
        host_traits (str): licensed traits of the host with --trait
        """
        if host.get("licenses") is None:
            return ''
        host_traits = list()
        for license in host['licenses']:
            host_traits.append(license_traits[license])
        return ' '.join(["--trait " + s for s in host_traits])

    def get_aggregates_to_add_host(self, host, license_aggregate):
        """Get aggregates for each host with specified licenses.

        Parameters:
        host (dict): dict of host information in inventory
        license_aggregate (dict): dict of licenses to aggregates

        Returns:
        host_aggregates (str): aggregates the host should be added to
        """
        if host.get("licenses") is None:
            return ''
        host_aggregates = list()
        for license in host.get("licenses"):
            host_aggregates.append(license_aggregate[license])
        return " ".join(host_aggregates)

    def get_aggregates_to_remove_host(self, host, license_aggregate):
        """Get aggregates that each host doesn't have licenses.

        Parameters:
        host (dict): dict of host information in inventory
        license_aggregate (dict): dict of licenses to aggregates

        Returns:
        aggregates (str): aggregates the host should be removed from
        """
        if host.get('licenses') is None:
            return " ".join(license_aggregate.values())
        aggregates = list()
        for license in \
                set(license_aggregate.keys()) - set(host.get("licenses")):
            aggregates.append(license_aggregate[license])
        return " ".join(aggregates)
