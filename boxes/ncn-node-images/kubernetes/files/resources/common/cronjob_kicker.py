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

import datetime
import logging
import logging.handlers
import subprocess

LOGGER = logging.getLogger('cronjob_kicker')
LOGGER.setLevel(logging.INFO)
LOG_FILENAME = '/var/log/cronjob_kicker.log'


def check_cronjob(name):
    k_time_ran_cmd = [
        'kubectl',
        'get',
        'cronjob',
        '-n',
        'services',
        name,
        '-ojsonpath={.status.lastScheduleTime}',
    ]
    p = subprocess.run(
        k_time_ran_cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        universal_newlines=True,
    )
    if p.returncode != 0:
        if 'NotFound' in p.stderr:
            LOGGER.info("%s cronjob wasn't found, ignoring", name)
            return
        raise Exception("Failed to get cronjob, stderr={}".format(p.stderr))
    job_time_str = p.stdout

    # if job_time_str is null, set a place holder time 
    # to avoid type mis match with last_sync_time
    if job_time_str == '':
        print('job_time_str null/empty, setting place holder time1')
        job_time_str = '2000-01-01T00:00:00Z'

    last_sync_time = datetime.datetime.strptime(
        job_time_str, '%Y-%m-%dT%H:%M:%SZ'
    )

    time_diff = datetime.datetime.utcnow() - last_sync_time

    if time_diff < datetime.timedelta(minutes=60):
        LOGGER.info("%s ran %s ago", name, time_diff)
        return

    LOGGER.info("%s hasn't run for %s, will recreate", name, time_diff)

    k_get_cronjob_cmd = [
        'kubectl',
        'get',
        'cronjob',
        '-n',
        'services',
        name,
        '-oyaml',
    ]
    p = subprocess.run(
        k_get_cronjob_cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        universal_newlines=True,
        check=True,
    )
    cronjob_yaml = p.stdout

    k_delete_cronjob_cmd = [
        'kubectl',
        'delete',
        'cronjob',
        '-n',
        'services',
        name,
    ]
    p = subprocess.run(
        k_delete_cronjob_cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        universal_newlines=True,
        check=True,
    )
    LOGGER.info("delete cronjob output: %s", p.stdout)

    k_create_cronjob_cmd = ['kubectl', 'create', '-f-']
    p = subprocess.run(
        k_create_cronjob_cmd,
        input=cronjob_yaml,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        universal_newlines=True,
        check=True,
    )
    LOGGER.info("create cronjob output: %s", p.stdout)

    # extra kick for unbound-manager
    if name == 'cray-dns-unbound-manager':
        k_patch_cronjob_cmd = [
            'kubectl',
            'patch',
            'cronjobs',
            '-n',
            'services',
            name,
            '-p',
            '{"spec" : {"suspend" : false }}'
        ]
        p = subprocess.run(
            k_patch_cronjob_cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            universal_newlines=True,
            check=True,
        )
        LOGGER.info(
            "Patching cronjob to make sure cronjob is enabled: %s",
            p.stdout
        )


def main():

    # set syslog handler
    syslog_handler = logging.handlers.SysLogHandler(address='/dev/log')

    # set log format
    log_format = logging.Formatter('%(asctime)s %(levelname)s %(message)s')

    # Add the log file handler
    log_file_handler = logging.handlers.RotatingFileHandler(
        LOG_FILENAME,
        maxBytes=1000000,
        backupCount=5,
    )

    # add log file format
    log_file_handler.setFormatter(log_format)

    # set the log file handler to logger
    LOGGER.addHandler(log_file_handler)
    LOGGER.addHandler(syslog_handler)

    CRONJOBS = [
        'sonar-sync',
        'sonar-jobs-watcher',
        'cray-dns-unbound-manager',
        'hms-discovery',
        'hms-postgresql-pruner',
    ]

    for cronjob in CRONJOBS:
        try:
            check_cronjob(cronjob)
        except Exception as e:
            LOGGER.error("Problem checking %s: %s", cronjob, e, exc_info=True)


if __name__ == "__main__":
    main()
