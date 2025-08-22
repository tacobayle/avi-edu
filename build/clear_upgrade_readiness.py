#!/usr/bin/python3

############################################################################
# ========================================================================
# Copyright 2022 VMware, Inc.  All rights reserved. VMware Confidential
# ========================================================================
###

import sys, os, django
sys.path.append("/opt/avi/python/bin/portal")
os.environ["DJANGO_SETTINGS_MODULE"] = "portal.settings_full"
django.setup()


import argparse, traceback
from avi.upgrade.upgrade_utils import notif_upgrade_status_info
from avi.upgrade.upgrade_utils import ds_get_all_upgradestatusinfo

def clear_upgrade_readiness(update=False, uuids = []):
    """
    Clean up Upgrade readiness
    """
    try:

        ds, tbl, key_list = ds_get_all_upgradestatusinfo()
        if uuids :
            key_list = uuids
        for key in key_list:
            obj = ds.get(tbl, key)
            usi_pb = obj['config']
            if usi_pb.HasField("upgrade_readiness"):
                usi_pb.ClearField('upgrade_readiness')
            if update:
                print("Updated USInfo: %s" % usi_pb.uuid)
                notif_upgrade_status_info(usi_pb)
            else:
               print("USInfo: %s" % usi_pb.uuid)

    except Exception as e:
        print("Error in clearing values for usinfo entry: %s" % str(e))
        traceback.print_exception()


if __name__ == "__main__":
        parser = argparse.ArgumentParser()
        parser.add_argument("--update", required=False, action="store_true", help="If provided, will clear readiness object for upgrade status info object")
        parser.add_argument("--uuids", required=False, nargs='*' , help="If provided, will clear readiness object for upgrade status info object for specific uuids")
        args = parser.parse_args()
        clear_upgrade_readiness(args.update, args.uuids)