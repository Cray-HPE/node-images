#!/usr/bin/python3
#
# MIT License
#
# (C) Copyright 2022 Hewlett Packard Enterprise Development LP
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
# OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
# ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.
#

import json
import os
import subprocess
import time
from argparse import ArgumentParser

import rados
from packaging import version
from prettytable import PrettyTable

"""
Start report block.
Basic report of the cluster for upgrade purposes.
Requires minimum podman version 3.4.4
"""


def print_function(print_data, service):
    print(print_data)


def fetch_status(service, cmd):
    try:
        cmd_results = cluster.mon_command(json.dumps(cmd), b'', timeout=5)
    except:
        print('something went wrong')

    refined_results = json.loads(cmd_results[1])
    table = PrettyTable(['Host', 'Daemon Type', 'ID', 'Version', 'Status'])
    table.title = service
    for s in range(len(refined_results)):
        host = (refined_results[s]["hostname"])
        type = (refined_results[s]["daemon_type"])
        id = (refined_results[s]["daemon_id"])
        status = (refined_results[s]["status_desc"])
        if status == "running":
            vers = (refined_results[s]["version"])
        else:
            vers = "unknown"
        table.add_row([host, type, id, vers, status])
    print_function(table, service)


"""
End report block.
"""

"""
Start upgrade check and execute block.
All functions related to checking for valid upgrade options or initiating an
upgrade should live below.
"""


def fetch_base_current_vers():
    cmd = {"prefix": "version", "format": "json"}
    cmd_results = cluster.mon_command(json.dumps(cmd), b'', timeout=5)
    results = json.loads(cmd_results[1])
    for key, value in results.items():
        current_version = str(value.split(' ')[2])
    return current_version


def fetch_per_service_count(service, cmd, base_version, current_version):
    base_counter = 0
    curr_counter = 0
    cmd_results = cluster.mon_command(json.dumps(cmd), b'', timeout=5)
    results = json.loads(cmd_results[1])
    for s in range(len(results)):
        status = (results[s]["status_desc"])
        if status == "running":
            type = (results[s]["daemon_type"])
            vers = (results[s]["version"])
            if vers == base_version:
                base_counter += 1
            elif vers == current_version:
                curr_counter += 1
    globals()[f"{service}_curr_count"] = curr_counter
    globals()[f"{service}_new_count"] = base_counter


def fetch_service_count_total(service, cmd, base_version):
    counter = 0
    total_count = 0
    cmd_results = cluster.mon_command(json.dumps(cmd), b'', timeout=5)
    results = json.loads(cmd_results[1])
    for s in range(len(results)):
        status = (results[s]["status_desc"])
        if status == "running":
            type = (results[s]["daemon_type"])
            vers = (results[s]["version"])
            if vers != base_version:
                counter += 1
        else:
            vers = "unknown"
    total_count += counter
    return total_count


def upgrade_check(new_vers, registry, current_version, quiet):
    registry_vers = json.loads(
        subprocess.check_output(
            [
                "podman",
                "search",
                registry + ":5000/ceph/ceph",
                "--list-tags",
                "--format=json",
            ]
        )
    )[0]['Tags']
    if version.parse(new_vers) == version.parse(current_version):
        upgrade_available = False
        if not quiet:
            print(
                "Your current version is the same as the proposed version %s" % current_version
                )
    elif new_vers in registry_vers:
        upgrade_available = True
        if not quiet:
            print(
                "Upgrade Available!!  The specified version %s has been found in the registry" % (
                    new_vers)
            )
    else:
        upgrade_available = False
        if not quiet:
            print(
                "Upgrade not available or the version specifeid is not a valid version"
            )
            print("Available versions are %s" % (registry_vers))
    return upgrade_available


def upgrade_execute(
        base_version,
        registry,
        upgrade_cmd,
        current_version,
        services,
        quiet,
        ):
    final_count = 0
    total_upgr = 0
    for service, cmd in services.items():
        total = fetch_service_count_total(service, cmd, base_version)
        final_count += total
    if not quiet:
        print(
            "Initiating Ceph upgrade from v%s to v%s" % (
                current_version, base_version)
            )
    cluster.mon_command(json.dumps(upgrade_cmd), b'', timeout=5)
    while total_upgr <= final_count:
        total_upgr = 0
        upgr_table = PrettyTable(
            ['Service', 'Total Current',
             'Total Upgraded']
            )
        upgr_table.title = "Upgrade Progress"
        time.sleep(5)
        if not quiet:
            os.system('clear')
        for service, cmd in services.items():
            old_vers_count = ("%s_curr_count" % (service))
            new_vers_count = ("%s_new_count" % (service))
            total_upgr = watch_upgrade(
                service,
                cmd,
                base_version,
                current_version,
                total_upgr,
                old_vers_count,
                new_vers_count,
                final_count,
            )
            old_count = int(globals()[old_vers_count])
            new_count = int(globals()[new_vers_count])
            upgr_table.add_row([service, old_count, new_count])
        if not quiet:
            print(upgr_table)
    upgrade_success = True
    return upgrade_success


def watch_upgrade(
        service,
        cmd,
        base_version,
        current_version,
        total_upgr,
        old_vers_count,
        new_vers_count,
        final_count
        ):
    fetch_per_service_count(service, cmd, base_version, current_version)
    if total_upgr == 0:
        total_upgr = int(globals()[new_vers_count])
    elif total_upgr > 0:
        total_upgr += int(globals()[new_vers_count])
    if total_upgr == final_count:
        total_upgr += 1
    return total_upgr


"""
End upgrade check and execute block
"""

"""
Start Cluster Communications block
This section is for connecting and disconnecting to the cluster.
All functions or checks related to connecting/disconnecting to the cluster should live below.
"""


def init_connect():
    global cluster
    try:
        cluster = rados.Rados(conffile='/etc/ceph/ceph.conf')
    except rados.ObjectNotFound:
        print('ceph.conf not found in /etc/ceph')
        exit(1)
    try:
        cluster.connect(1)
    except rados.InvalidArgumentError:
        exit(2)


def disconnect():
    cluster.shutdown()


"""
End Cluster Communications block
"""


def main():
    parser = ArgumentParser(description='Ceph upgrade script')
    parser.add_argument(
        '--report',
        required=False,
        dest='report',
        action='store_true',
        help='Provides a report of the state and versions of ceph'
        )
    parser.add_argument(
        '--version',
        required=False,
        type=str,
        dest='version',
        help='The target version to upgrade to or to check against. Format '
             'example v15.2.15'
        )
    parser.add_argument(
        '--registry',
        required=False,
        type=str,
        # default='registry.local:5000',
        dest='registry',
        help='The registry where ceph container images are stored'
        )
    parser.add_argument(
        '--upgrade',
        required=False,
        dest='upgrade',
        action='store_true',
        help='Upgrade toggle.  Defaults to False'
        )
    parser.add_argument(
        '--quiet',
        required=False,
        dest='quiet',
        action='store_true',
        help='Toggle to enable/disable visual output'
        )

    args = parser.parse_args()

    ## Provide 2 version strings to accomdate better output checking

    if args.version is not None:
        if args.version.startswith('v'):
            base_version = str(args.version.split('v', 2)[1])
            pretty_version = args.version
        elif not args.version.startswith('v'):
            base_version = args.version
            pretty_version = 'v' + args.version

    ## Set cmds ##

    mon = {"prefix": "orch ps", "daemon_type": "mon", "format": "json"}
    mgr = {"prefix": "orch ps", "daemon_type": "mgr", "format": "json"}
    osd = {"prefix": "orch ps", "daemon_type": "osd", "format": "json"}
    mds = {"prefix": "orch ps", "daemon_type": "mds", "format": "json"}
    rgw = {"prefix": "orch ps", "daemon_type": "rgw", "format": "json"}
    crash = {"prefix": "orch ps", "daemon_type": "crash", "format": "json"}

    ## Build dictionary ##

    """
    The order of the services is following the default upgrade order when using
    the ceph orchestrator.  Please do not change this.
    """

    services = {
        "MGR": mgr,
        "MON": mon,
        "Crash": crash,
        "OSD": osd,
        "MDS": mds,
        "RGW": rgw
    }

    if args.report:
        init_connect()
        for service, cmd in services.items():
            fetch_status(service, cmd)
        disconnect()

    if (args.version is not None and (
            args.registry is not None and args.upgrade is False)):
        init_connect()
        current_version = fetch_base_current_vers()
        upgrade_check(
            pretty_version,
            args.registry,
            current_version,
            args.quiet,
            )
        disconnect()

    elif (args.registry is not None and (
            args.version is not None or args.upgrade is True)):
        init_connect()
        current_version = fetch_base_current_vers()
        upgrade_cmd = {
            "prefix": "orch upgrade start",
            "image": args.registry + "/ceph/ceph:" + args.version
        }
        upgrade_proceed = upgrade_check(
            pretty_version,
            args.registry,
            current_version,
            args.quiet,
            )
        if upgrade_proceed:
            upgrade_success = upgrade_execute(
                base_version,
                args.registry,
                upgrade_cmd,
                current_version,
                services,
                args.quiet,
                )
            if upgrade_success:
                disconnect()
                exit(0)
            else:
                disconnect()
                exit(1)

    elif args.version is not None and args.registry is None:
        print("The --version option requires --registry option")

    elif (args.registry is not None and (
            args.version is None or args.upgrade is True)):
        print(
            "The registry flag requires --version and/or --upgrade to be set"
            )

    elif args.upgrade and (args.version is None or args.registry is None):
        print("Upgrade requires both --registry and --version to be set")


if __name__ == '__main__':
    main()
