###########################################
#
# defaults for the bcpc.bootstrap settings
#
###########################################
#
# A value of nil means to let the Ubuntu installer work it out - it
# will try to find the nearest one. However the selected mirror is
# often slow.
default['bcpc']['bootstrap']['mirror'] = nil
#
# if you do specify a mirror, you can adjust the file path that comes
# after the hostname in the URL here
default['bcpc']['bootstrap']['mirror_path'] = "/ubuntu"
#
# worked example for the columbia mirror mentioned above which has a
# non-standard path
#default['bcpc']['bootstrap']['mirror']      = "mirror.cc.columbia.edu"
#default['bcpc']['bootstrap']['mirror_path'] = "/pub/linux/ubuntu/archive"

# Define the kernel to be installed by preseed. By default, track current HWE kernel
default['bcpc']['bootstrap']['preseed_kernel'] = "linux-image-virtual-lts-xenial"

# Device to install to for legacy BIOS installations
default['bcpc']['bootstrap']['bios_boot_device'] = '/dev/sda'

# Cobbler profile to use for UEFI
default['bcpc']['bootstrap']['uefi_profile'] = 'bcpc_host_uefi'

# Device to install to for UEFI installations
default['bcpc']['bootstrap']['uefi_boot_device'] = '/dev/nvme0n1'

###########################################
#
#  Bootstrap tftpd settings
#
###########################################
#
# Address and port to listen
default['bcpc']['tftpd']['address'] = ':69'
