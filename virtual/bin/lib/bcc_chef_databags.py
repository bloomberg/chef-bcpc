# Copyright 2022, Bloomberg Finance L.P.
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

import base64
from builtins import FileExistsError
import os
import secrets
import string
import struct
import subprocess
import time
import uuid

from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
from cryptography.hazmat.primitives.serialization.ssh import \
    serialize_ssh_private_key
from cryptography.hazmat.primitives.serialization.ssh import \
    serialize_ssh_public_key
from cryptography import x509
from OpenSSL import crypto
import yaml


class APISSL:

    CA_KEY_SIZE = 2048
    CA_CRT_YEARS_VALID = 5
    CA_SIGNATURE_ALGO = "sha256"

    def __init__(self):

        # Create CA key pair
        self.__ca_key = crypto.PKey()
        self.__ca_key.generate_key(crypto.TYPE_RSA, self.CA_KEY_SIZE)

        # Define alt_names
        self.__alt_names = ','.join([
            'DNS:{}'.format('openstack.bcpc.example.com'),
            'DNS:localhost',
            'IP:10.65.0.254'
        ]).encode()

        # Create the CA certificate
        self.__ca = crypto.X509()
        self.__ca.get_subject().C = "US"
        self.__ca.get_subject().ST = "New York"
        self.__ca.get_subject().L = "New York"
        self.__ca.get_subject().O = "Bloomberg LP" # noqa
        self.__ca.get_subject().OU = "ENG Cloud Infrastructure"
        self.__ca.get_subject().CN = "openstack.bcpc.example.com"
        self.__ca.set_version(2)
        self.__ca.set_serial_number(x509.random_serial_number())
        self.__ca.gmtime_adj_notBefore(0)
        self.__ca.gmtime_adj_notAfter(
                self.CA_CRT_YEARS_VALID * 365 * 24 * 60 * 60)
        self.__ca.set_issuer(self.__ca.get_subject())
        self.__ca.set_pubkey(self.__ca_key)

        # Add certificate extensions
        self.__ca.add_extensions([
            # Note: This CA will only issue end-entity certificates, hence
            # pathlen == 0
            crypto.X509Extension(b"basicConstraints", True,
                                 b"CA:TRUE, pathlen:0"),
            crypto.X509Extension(b'subjectAltName', False,
                                 self.__alt_names)
        ])

        # Self-sign the certificate
        self.__ca.sign(self.__ca_key, self.CA_SIGNATURE_ALGO)

    def crt(self):
        certificate = crypto.dump_certificate(crypto.FILETYPE_PEM,
                                              self.__ca)
        return base64.b64encode(certificate).decode()

    def key(self):
        private_key = crypto.dump_privatekey(crypto.FILETYPE_PEM,
                                             self.__ca_key)
        return base64.b64encode(private_key).decode()


class EtcdSSL:

    CA_KEY_SIZE = 2048
    CA_CRT_YEARS_VALID = 5
    CA_SIGNATURE_ALGO = "sha256"

    END_ENTITY_KEY_SIZE = 2048
    END_ENTITY_CRT_YEARS_VALID = 5
    END_ENTITY_SIGNATURE_ALGO = "sha256"

    def __init__(self):

        self.__certs = {}

        # Create CA key pair
        self.__ca_key = crypto.PKey()
        self.__ca_key.generate_key(crypto.TYPE_RSA, self.CA_KEY_SIZE)

        # Create the CA certificate
        self.__ca = crypto.X509()
        self.__ca.get_subject().C = "US"
        self.__ca.get_subject().ST = "New York"
        self.__ca.get_subject().L = "New York"
        self.__ca.get_subject().O = "Bloomberg LP" # noqa
        self.__ca.get_subject().OU = "ENG Cloud Infrastructure"
        self.__ca.get_subject().CN = "ETCD Certificate Authority"
        self.__ca.set_version(2)
        self.__ca.set_serial_number(x509.random_serial_number())
        self.__ca.gmtime_adj_notBefore(0)
        self.__ca.gmtime_adj_notAfter(
                self.CA_CRT_YEARS_VALID * 365 * 24 * 60 * 60)
        self.__ca.set_issuer(self.__ca.get_subject())
        self.__ca.set_pubkey(self.__ca_key)

        # Add certificate extensions
        self.__ca.add_extensions([
            # Note: This CA will only issue end-entity certificates, hence
            # pathlen == 0
            crypto.X509Extension(b"basicConstraints", True,
                                 b"CA:TRUE, pathlen:0"),
            crypto.X509Extension(b"keyUsage", True,
                                 b"keyCertSign, cRLSign"),
            crypto.X509Extension(b"subjectKeyIdentifier", False,
                                 b"hash", subject=self.__ca)
        ])

        # Add authority key identifier extension only once other extensions
        # have been added
        self.__ca.add_extensions([
            crypto.X509Extension(b"authorityKeyIdentifier", False,
                                 b"keyid:always", issuer=self.__ca)
        ])

        # Self-sign the certificate
        self.__ca.sign(self.__ca_key, self.CA_SIGNATURE_ALGO)

        # Create server and client certificates signed by the CA
        for client in ['client-ro', 'client-rw', 'server']:

            # Create the end entity key
            self.__certs[client] = {}
            self.__certs[client]['key'] = crypto.PKey()
            self.__certs[client]['key'].generate_key(
                    crypto.TYPE_RSA, self.END_ENTITY_KEY_SIZE)

            # Create the end entity certificate
            self.__certs[client]['cert'] = crypto.X509()
            self.__certs[client]['cert'].get_subject().C = "US"
            self.__certs[client]['cert'].get_subject().ST = "New York"
            self.__certs[client]['cert'].get_subject().L = "New York"
            self.__certs[client]['cert'].get_subject().O = \
                "Bloomberg LP" # noqa
            self.__certs[client]['cert'].get_subject().OU = \
                "ENG Cloud Infrastructure"
            self.__certs[client]['cert'].get_subject().CN = client
            self.__certs[client]['cert'].set_version(2)
            self.__certs[client]['cert'].set_serial_number(
                    x509.random_serial_number())
            self.__certs[client]['cert'].gmtime_adj_notBefore(0)
            self.__certs[client]['cert'].gmtime_adj_notAfter(
                self.END_ENTITY_CRT_YEARS_VALID * 365 * 24 * 60 * 60
            )
            self.__certs[client]['cert'].set_issuer(self.__ca.get_issuer())
            self.__certs[client]['cert'].set_pubkey(
                self.__certs[client]['key']
            )

            # Add common certificate extensions
            self.__certs[client]['cert'].add_extensions([
                crypto.X509Extension(b"basicConstraints", True,
                                     b"CA:FALSE"),
                crypto.X509Extension(b"subjectKeyIdentifier", False,
                                     b"hash",
                                     subject=self.__certs[client]['cert']),
                crypto.X509Extension(b"authorityKeyIdentifier", False,
                                     b"keyid:always", issuer=self.__ca),
                crypto.X509Extension(b"keyUsage", True,
                                     b"digitalSignature, keyEncipherment")
            ])

            # Add additional certificate extensions
            if client == 'server':
                alt_names = ','.join([
                    'IP:10.65.0.2',
                    'IP:10.65.0.4',
                    'IP:10.65.0.16',
                    'IP:10.65.0.18',
                    'IP:10.65.0.32',
                    'IP:10.65.0.34',
                    'IP:127.0.0.1'
                ]).encode()

                self.__certs[client]['cert'].add_extensions([
                    crypto.X509Extension(b"extendedKeyUsage", False,
                                         b"serverAuth, clientAuth"),
                    crypto.X509Extension(b'subjectAltName', False,
                                         alt_names)
                ])
            else:
                self.__certs[client]['cert'].add_extensions([
                    crypto.X509Extension(b"extendedKeyUsage", False,
                                         b"clientAuth")
                ])

            # Sign the certificate with the CA key
            self.__certs[client]['cert'].sign(
                    self.__ca_key, self.END_ENTITY_SIGNATURE_ALGO)

    def ca_crt(self):
        dump = crypto.dump_certificate(crypto.FILETYPE_PEM,
                                       self.__ca)
        return base64.b64encode(dump).decode()

    def ca_key(self):
        dump = crypto.dump_privatekey(crypto.FILETYPE_PEM,
                                      self.__ca_key)
        return base64.b64encode(dump).decode()

    def server_crt(self):
        dump = crypto.dump_certificate(crypto.FILETYPE_PEM,
                                       self.__certs['server']['cert'])
        return base64.b64encode(dump).decode()

    def server_key(self):
        dump = crypto.dump_privatekey(crypto.FILETYPE_PEM,
                                      self.__certs['server']['key'])
        return base64.b64encode(dump).decode()

    def client_ro_crt(self):
        dump = crypto.dump_certificate(crypto.FILETYPE_PEM,
                                       self.__certs['client-ro']['cert'])
        return base64.b64encode(dump).decode()

    def client_ro_key(self):
        dump = crypto.dump_privatekey(crypto.FILETYPE_PEM,
                                      self.__certs['client-ro']['key'])
        return base64.b64encode(dump).decode()

    def client_rw_crt(self):
        dump = crypto.dump_certificate(crypto.FILETYPE_PEM,
                                       self.__certs['client-rw']['cert'])
        return base64.b64encode(dump).decode()

    def client_rw_key(self):
        dump = crypto.dump_privatekey(crypto.FILETYPE_PEM,
                                      self.__certs['client-rw']['key'])
        return base64.b64encode(dump).decode()


class SSH:
    def __init__(self):
        # Note: pyopenssl 22.0.0 does not support Ed25519PrivateKey keys,
        # but support is present on master. Until then, we will use the raw
        # cryptography functions instead.
        # self.__key = crypto.PKey.from_cryptography_key(
        #         Ed25519PrivateKey.generate())
        self.__key = Ed25519PrivateKey.generate()

    @property
    def key(self):
        return self.__key

    def public(self):
        # key = self.key.publickey().exportKey('OpenSSH')
        key = serialize_ssh_public_key(self.key.public_key())
        return base64.b64encode(key).decode()

    def private(self):
        # key = self.key.exportKey('PEM')
        key = serialize_ssh_private_key(self.key)
        return base64.b64encode(key).decode()


class BCCChefDatabags:

    def __init__(self):
        self.__etcd_ssl = EtcdSSL()
        self.__nova_ssh = SSH()
        self.__ssh = SSH()
        self.__api_ssl = APISSL()

    @property
    def etcd_ssl(self):
        return self.__etcd_ssl

    @property
    def nova_ssh(self):
        return self.__nova_ssh

    @property
    def ssh(self):
        return self.__ssh

    @property
    def api_ssl(self):
        return self.__api_ssl

    def generate_ceph_key(self):
        key = os.urandom(16)
        header = struct.pack('<hiih', 1, int(time.time()), 0, len(key))
        return base64.b64encode(header + key).decode()

    def generate_fernet(self):
        return base64.urlsafe_b64encode(os.urandom(32)).decode()

    def generate_string(self, length=32):
        return ''.join(
            secrets.choice(string.ascii_letters) for i in range(length)
        )

    def generate_uuid(self):
        return str(uuid.uuid4())

    def save(self, force=False):
        cmd = 'git rev-parse --show-toplevel'
        root = subprocess.check_output(cmd.split(" ")).decode().rstrip('\n')
        fp = '{0}/{1}'.format(root, 'ansible/group_vars/all/chef_databags.yml')

        if os.path.isfile(fp) and not force:
            msg = '{} exists.\nWill not overwrite without force.'
            msg = msg.format(fp)
            raise FileExistsError(msg)

        with open(fp, 'w') as file:
            yaml.dump(
                self.generate(),
                file, default_flow_style=False, indent=2
            )

    def generate(self):

        config = {
            'id': 'config',
            'openstack': {
                'admin': {
                    'password': self.generate_string()
                }
            },
            'apache': {
                'status': {
                    'username': 'apache_status',
                    'password': self.generate_string()
                }
            },
            'ceph': {
                'fsid': self.generate_uuid(),
                'mon': {
                    'key': self.generate_ceph_key()
                },
                'bootstrap': {
                    'mds': {
                        'key': self.generate_ceph_key()
                    },
                    'mgr': {
                        'key': self.generate_ceph_key()
                    },
                    'osd': {
                        'key': self.generate_ceph_key()
                    },
                    'rgw': {
                        'key': self.generate_ceph_key()
                    },
                    'rbd': {
                        'key': self.generate_ceph_key()
                    },
                },
                'client': {
                    'admin': {
                        'key': self.generate_ceph_key()
                    },
                    'cinder': {
                        'key': self.generate_ceph_key()
                    },
                    'glance': {
                        'key': self.generate_ceph_key()
                    }
                },
            },
            'etcd': {
                'users': [
                    {
                        'username': 'root',
                        'password': self.generate_string()
                    },
                    {
                        'username': 'server',
                        'password': self.generate_string()
                    },
                    {
                        'username': 'client-ro',
                        'password': self.generate_string()
                    },
                    {
                        'username': 'client-rw',
                        'password': self.generate_string()
                    },
                ],
                'ssl': {
                    'ca': {
                        'crt': self.etcd_ssl.ca_crt(),
                        'key': self.etcd_ssl.ca_key(),
                    },
                    'server': {
                        'crt': self.etcd_ssl.server_crt(),
                        'key': self.etcd_ssl.server_key(),
                    },
                    'client-ro': {
                        'crt': self.etcd_ssl.client_ro_crt(),
                        'key': self.etcd_ssl.client_ro_key(),
                    },
                    'client-rw': {
                        'crt': self.etcd_ssl.client_rw_crt(),
                        'key': self.etcd_ssl.client_rw_key(),
                    },
                }
            },
            'powerdns': {
                'creds': {
                    'db': {
                        'username': 'pdns',
                        'password': self.generate_string()
                    },
                    'webserver': {'password': self.generate_string()},
                    'api': {'key': self.generate_string()},
                }
            },
            'proxysql': {
                'creds': {
                    'db': {
                        'username': 'psql_monitor',
                        'password': self.generate_string(),
                    },
                    'admin': {
                        'username': 'psql_admin',
                        'password': self.generate_string(),
                    },
                    'stats': {
                        'username': 'psql_stats',
                        'password': self.generate_string(),
                    },
                },
            },
            'keystone': {
                'db': {
                    'username': 'keystone',
                    'password': self.generate_string()
                },
                'fernet': {
                    'keys': {
                        'primary': self.generate_fernet(),
                        'secondary': self.generate_fernet(),
                        'staged': self.generate_fernet(),
                    }
                }
            },
            'glance': {
                'creds': {
                    'db': {
                        'username': 'glance',
                        'password': self.generate_string()
                    },
                    'os': {
                        'username': 'glance',
                        'password': self.generate_string()
                    },
                }
            },
            'cinder': {
                'creds': {
                    'db': {
                        'username': 'cinder',
                        'password': self.generate_string()
                    },
                    'os': {
                        'username': 'cinder',
                        'password': self.generate_string()
                    },
                }
            },
            'heat': {
                'creds': {
                    'db': {
                        'username': 'heat',
                        'password': self.generate_string()
                    },
                    'os': {
                        'username': 'heat',
                        'password': self.generate_string()
                    },
                }
            },
            'horizon': {'secret': self.generate_string()},
            'libvirt': {'secret': self.generate_uuid()},
            'neutron': {
                'creds': {
                    'db': {
                        'username': 'neutron',
                        'password': self.generate_string()
                    },
                    'os': {
                        'username': 'neutron',
                        'password': self.generate_string()
                    },
                }
            },
            'nova': {
                'creds': {
                    'db': {
                        'username': 'nova',
                        'password': self.generate_string()
                    },
                    'os': {
                        'username': 'nova',
                        'password': self.generate_string()
                    },
                },
                'ssh': {
                    'crt': self.nova_ssh.public(),
                    'key': self.nova_ssh.private()
                }
            },
            'placement': {
                'creds': {
                    'db': {
                        'username': 'placement',
                        'password': self.generate_string()
                    },
                    'os': {
                        'username': 'placement',
                        'password': self.generate_string()
                    },
                }
            },
            'mysql': {
                'users': {
                    'sst': {'password': self.generate_string()},
                    'root': {'password': self.generate_string()},
                    'check': {'password': self.generate_string()},
                }
            },
            'rabbit': {
                'username': 'guest',
                'password': self.generate_string(),
                'cookie': self.generate_string()
            },
            'haproxy': {
                'username': 'haproxy',
                'password': self.generate_string(),
            },
            'ssh': {
                'public': self.ssh.public(),
                'private': self.ssh.private()
            },
            'ssl': {
                'key': self.api_ssl.key(),
                'crt': self.api_ssl.crt(),
                'intermediate': None
            },
            'watcher': {
                'creds': {
                    'db': {
                        'username': 'watcher',
                        'password': self.generate_string()
                    },
                    'os': {
                        'username': 'watcher',
                        'password': self.generate_string()
                    }
                }
            }
        }

        zones = {
            'id': 'zones',
            'dev': {
                'ceph': {
                    'client': {
                        'cinder': {'key': self.generate_ceph_key()}
                    }
                },
                'libvirt': {'secret': self.generate_uuid()}
            }
        }

        return {'chef_databags': [config, zones]}
