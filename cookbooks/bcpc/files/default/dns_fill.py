#!/usr/bin/env python

"""
DNS popper

Asks openstack about all the running instances that currently have floats
then creates a CNAME record to point to the public-X.X.X.X username

"""
import json
import keystoneclient
from keystoneclient import exceptions as kc_exceptions
import MySQLdb as mdb
import platform
import re
import requests
import subprocess
import syslog

if platform.python_version() == '2.7.6':
    from requests.packages.urllib3.exceptions import InsecureRequestWarning, \
        InsecurePlatformWarning, SNIMissingWarning
    requests.packages.urllib3.disable_warnings(InsecureRequestWarning)
    requests.packages.urllib3.disable_warnings(InsecurePlatformWarning)
    requests.packages.urllib3.disable_warnings(SNIMissingWarning)


class dns_popper(object):
    def __init__(self, config):
        self.config = config
        self.api_version = config["IDENTITY_URI"]
        auth_params = {
            'username': config['OS_USERNAME'],
            'password': config['OS_PASSWORD'],
            'insecure': True
        }
        auth_params['auth_url'] = config['OS_AUTH_URL'] + \
            "/%s/" % self.api_version
        if self.api_version == 'v2.0':
            from keystoneclient.v2_0 import client as kclient
            auth_params['tenant_name'] = config['OS_PROJECT_NAME']
        else:
            from keystoneclient.v3 import client as kclient
            auth_params['project_name'] = config['OS_PROJECT_NAME']
        self.keystone = kclient.Client(**auth_params)

        dbc = self.config["db"]
        self.db_con = mdb.connect(
            dbc["host"], dbc["user"], dbc["password"], db=dbc["name"])

        c = self.db_con.cursor()
        c.execute("select id, name from domains where name=%s",
                  self.config["domain"])
        rows = c.fetchall()
        if len(rows) != 1:
            syslog.syslog(
                syslog.LOG_ERROR,
                "Cannot find unique domain '%s' in pdns DB" %
                (self.config["domain"]))
            raise Exception(
                "Cannot find unique domain '%s' in pdns DB" %
                (self.config["domain"]))
        self.domain_id = int(rows[0][0])

    def generate_records_from_vms(self):
        """
        Get all the vms with a float attached
        """
        # The replacements we used to do in SQL
        c = self.db_con.cursor()
        c.execute(
            "SELECT i.uuid, i.display_name, i.project_id, n.address "
            "FROM nova.instances i "
            "JOIN nova.fixed_ips f ON i.uuid = f.instance_uuid "
            "JOIN nova.floating_ips n ON f.id = n.fixed_ip_id "
            "WHERE i.deleted = 0 AND i.project_id IS NOT NULL")
        servers = c.fetchall()

        rc = []

        for server in servers:
            project_id = server[2]
            try:
                if self.api_version == 'v2.0':
                    project = self.keystone.tenants.get(project_id)
                else:
                    project = self.keystone.projects.get(project_id)
            except kc_exceptions.NotFound as e:
                syslog.syslog(syslog.LOG_NOTICE, e.args[0])
                continue

            pname = make_rfc1123_compliant(project.name)
            sname = make_rfc1123_compliant(server[1])
            address = server[3]

            float_name = ("public-" + str(address).replace(".", "-") + "." +
                 self.config["domain"])
            dnsname = str(
                ("%s.%s.%s" % (sname,  pname, self.config["domain"])).lower())
            rc.append((dnsname, "CNAME", float_name))
            project_info = {
                'uuid': server[0],
                'project': {
                    'name': project.name[:40],
                    'description': project.description[:40]
                }
            }
            # PowerDNS requires \ and " to be escaped in TXT records
            project_info_str = json.dumps(project_info)
            project_info_str = project_info_str.replace('"', r'\"')
            rc.append((float_name, "TXT", project_info_str))

        return rc

    def get_records_from_db(self):
        c = self.db_con.cursor()
        c.execute(
            "SELECT name, type, content FROM records WHERE type IN "
            "('CNAME', 'TXT') AND bcpc_record_type='DYNAMIC'")
        rows = []
        for row in c.fetchall():
            rows.append((row[0], row[1], row[2]))
        return rows

    def update_db(self, db_rows, nova_rows):
        ds = set(db_rows)
        ns = set(nova_rows)
        to_delete = ds - ns
        to_add = ns - ds
        c = self.db_con.cursor()
        try:
            if to_delete:
                syslog.syslog(
                    syslog.LOG_NOTICE, "Deleting %d records from pdns" %
                    len(to_delete))
                c.executemany(
                    "DELETE FROM records WHERE name=%s AND type=%s "
                    "AND content=%s AND bcpc_record_type='DYNAMIC'",
                    to_delete)
            if to_add:
                syslog.syslog(
                    syslog.LOG_NOTICE, "Adding %d CNAMEs to pdns" %
                    len(to_add))
                c.executemany(
                    "INSERT INTO records "
                    "(domain_id, name, type, content, ttl, bcpc_record_type) "
                    "VALUES (%s, %s, %s, %s, 300, 'DYNAMIC')",
                    [(self.domain_id,
                      rec[0],
                      rec[1],
                      rec[2]) for rec in to_add])
            self.db_con.commit()
        except mdb.Error, e:
            self.db_con.rollback()
            msg = "DB changes failed: %d: %s" % (e.args[0], e.args[1])
            syslog.syslog(syslog.LOG_ERR, msg)
            sys.stderr.write(msg + "\n")
            sys.stderr.flush()
            sys.exit(1)

    def update_zone(self):
        try:
            cmd = subprocess.Popen(['/usr/local/bin/dns-update-zone.sh',
                                   self.config['domain']])
            cmd.communicate()
        except subprocess.CalledProcessError, e:
            syslog.syslog(
                syslog.LOG_ERROR,
                "Unable to update zone %s" % self.config['domain'])
        else:
            syslog.syslog(
                syslog.LOG_INFO,
                "Updated zone %s " % self.config['domain'])


def make_rfc1123_compliant(name):
    """
    Renders the given string in an RFC-1123 compliant way:
    - 63 character max length
    - allowed chars are [a-z0-9\-]
    - cannot start or end with hyphen

    In addition:
    - don't allow consecutive hyphens (not sure if allowed)
    """
    import re

    allowed_chars = re.compile(r'[a-z0-9\-]')
    output_name = ''
    # replace illegal characters after lowercasing
    for char in name.lower():
        if len(allowed_chars.findall(char)):
            output_name += char
        elif char == '&':
            output_name += '-and-'
        else:
            output_name += '-'

    # don't let it start with hyphen
    if output_name[0] == '-':
        output_name = 'hyphen' + output_name

    # don't allow consecutive hyphens (jury is out on whether this is
    # legal but we will not allow it)
    output_name = re.sub(r'\-+', '-', output_name)

    # truncate to 63 characters maximum
    output_name = output_name[0:63]

    # don't let it end with hyphen (will need to truncate again)
    if output_name[len(output_name)-1] == '-':
        # if longer than 57 chars, will need to trim off the end
        max_length_without_trim = 57
        if len(output_name) <= max_length_without_trim:
            output_name += 'hyphen'
        else:
            # add 1 here to account for hyphen
            count_to_remove = (
                1 + len(output_name) - max_length_without_trim)
            output_name = (
                output_name[0:len(output_name)-count_to_remove] +
                '-hyphen')

    return output_name


def c_load_config(path):
    import yaml
    return yaml.load(open(path))


def c_run(args):
    config = c_load_config(args.config)
    dnsp = dns_popper(config)
    nova_rows = dnsp.generate_records_from_vms()
    db_rows = dnsp.get_records_from_db()
    dnsp.update_db(db_rows, nova_rows)
    dnsp.update_zone()


def c_dump(args):
    config = c_load_config(args.config)
    dnsp = dns_popper(config)
    nrec = dnsp.generate_records_from_vms()
    dbrec = dnsp.get_records_from_db()
    print(
        json.dumps(
            {
                'expected_records': nrec,
                'database_records': dbrec
            }, indent=4
        )
    )


if __name__ == '__main__':
    import argparse
    import sys
    parser = argparse.ArgumentParser()
    parser.add_argument(
        '-c', '--config', dest="config",
        default="config.yml", help='Config file')
    subparsers = parser.add_subparsers(help="commands")
    parser_run = subparsers.add_parser(
        'run', help='Sync DNS DB with nova state')
    parser_run.set_defaults(func=c_run)
    parser_dump = subparsers.add_parser('dump', help='dump current state')
    parser_dump.set_defaults(func=c_dump)
    args = parser.parse_args()
    args.func(args)
    sys.exit(0)
