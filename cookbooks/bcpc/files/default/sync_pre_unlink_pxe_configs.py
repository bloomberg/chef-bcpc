#!/usr/bin/python
from cobbler import api
from cobbler import utils
import os


def register():
    """This is a pre-sync trigger"""
    return '/var/lib/cobbler/triggers/sync/pre/*'


def run(api, args, logger):
    """Removes the symlinks. Similar to BootSync.clean_trees()"""
    rc = 0
    tftp_basedir = utils.tftpboot_location()
    try:
        bootmodes = ['bios', 'efi64']
        for b in bootmodes:
            # logger is uninitialized for some reason at this point
            if logger is not None:
                logger.info('Removing PXE configs for %s' % b.upper())
            pxecfg_path = os.path.join(tftp_basedir, b, 'pxelinux.cfg')
            if os.path.islink(pxecfg_path):
                os.unlink(pxecfg_path)
    except OSError as err:
        rc = err.errno

    return rc
