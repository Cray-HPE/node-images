#!/usr/bin/python3
# Copyright 2019-2020 Hewlett Packard Enterprise Development LP

import datetime
import logging
import logging.handlers
import subprocess


LOGGER = logging.getLogger('cronjob_kicker')


def check_cronjob(name):
    k_time_ran_cmd = [
        'kubectl', 'get', 'cronjob', '-n', 'services', name,
        '-ojsonpath={.status.lastScheduleTime}']
    p = subprocess.run(
        k_time_ran_cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        universal_newlines=True)
    if p.returncode != 0:
        if 'NotFound' in p.stderr:
            LOGGER.info("%s cronjob wasn't found, ignoring", name)
            return
        raise Exception("Failed to get cronjob, stderr={}".format(p.stderr))
    if p.stdout == '':
        LOGGER.info("%s cronjob hasn't run yet, ignoring", name)
        return
    job_time_str = p.stdout

    last_sync_time = datetime.datetime.strptime(
        job_time_str, '%Y-%m-%dT%H:%M:%SZ')

    time_diff = datetime.datetime.utcnow() - last_sync_time

    if time_diff < datetime.timedelta(minutes=4):
        LOGGER.info("%s ran %s ago", name, time_diff)
        return

    LOGGER.info("%s hasn't run for %s, will recreate", name, time_diff)

    k_get_cronjob_cmd = [
        'kubectl', 'get', 'cronjob', '-n', 'services', name, '-oyaml']
    p = subprocess.run(
        k_get_cronjob_cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        universal_newlines=True, check=True)
    cronjob_yaml = p.stdout

    k_delete_cronjob_cmd = [
        'kubectl', 'delete', 'cronjob', '-n', 'services', name]
    p = subprocess.run(
        k_delete_cronjob_cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        universal_newlines=True, check=True)
    LOGGER.info("delete cronjob output: %s", p.stdout)

    k_create_cronjob_cmd = ['kubectl', 'create', '-f-']
    p = subprocess.run(
        k_create_cronjob_cmd, input=cronjob_yaml, stdout=subprocess.PIPE,
        stderr=subprocess.PIPE, universal_newlines=True, check=True)
    LOGGER.info("create cronjob output: %s", p.stdout)


def main():
    syslog_handler = logging.handlers.SysLogHandler(address='/dev/log')
    logging.basicConfig(level=logging.INFO, handlers=[syslog_handler])

    CRONJOBS = ['sonar-sync', 'sonar-jobs-watcher', 'cray-dns-unbound-manager', 'hms-discovery', 'hms-postgresql-pruner']

    for cronjob in CRONJOBS:
        try:
            check_cronjob(cronjob)
        except Exception as e:
            LOGGER.error("Problem checking %s: %s", cronjob, e, exc_info=True)


if __name__ == "__main__":
    main()
