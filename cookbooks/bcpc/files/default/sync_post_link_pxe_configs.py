#!/usr/bin/python
from cobbler import api
from cobbler import utils
import os


def register():
    """This is a post-sync trigger"""
    return '/var/lib/cobbler/triggers/sync/post/*'


def run(api, args, logger):
    """Creates the necessary symlinks for both BIOS and UEFI PXE configs"""
    rc = 0
    tftp_basedir = utils.tftpboot_location()
    pxecfg_dir = os.path.join(tftp_basedir, 'pxelinux.cfg')
    if os.path.isdir(pxecfg_dir):
        try:
            bootmodes = ['bios', 'efi64']
            for b in bootmodes:
                logger.info('Linking PXE configs for %s' % b.upper())
                pxecfg_path = os.path.join(tftp_basedir, b, 'pxelinux.cfg')
                if not os.path.islink(pxecfg_path):
                    os.symlink('../pxelinux.cfg', pxecfg_path)
        except OSError as err:
            logger.error(err)
            rc = err.errno

    return rc
