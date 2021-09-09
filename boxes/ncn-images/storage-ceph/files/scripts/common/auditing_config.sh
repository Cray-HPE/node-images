# Enables/disables the auditing software.
# If "ncn-mgmt-node-auditing-enabled": true then will copy configuration
# into place and restart the services, else will disable and stop the service
# Will be disables by default in vshasta

export CRAYSYS_TYPE=$(craysys type get)
if [ $CRAYSYS_TYPE != "google" ]; then
  export CRAYSYS_AUDITING=$(craysys metadata get ncn-mgmt-node-auditing-enabled)
fi

function configure_auditing() {
if [[ $CRAYSYS_AUDITING = "true" && $CRAYSYS_TYPE = "metal" ]]; then
  echo "Copying in Cray auditing config files"
  cp /srv/cray/resources/common/audit/* /etc/audit
  if [ ! -d /var/log/audit/HostOS ]; then
    echo "Create dir /var/log/audit/HostOS/"
    mkdir /var/log/audit/HostOS/
  fi
  echo "Restarting ncn auditing service"
  systemctl restart auditd.service
elif [[ $CRAYSYS_AUDITING = "false" && $CRAYSYS_TYPE = "metal" ]]; then
  echo "Using generic auditing configuration"
elif [ $CRAYSYS_TYPE = "google" ]; then
  echo "Disabling auditing on vshasta"
  systemctl disable auditd.service
  systemctl stop auditd.service
  systemctl status auditd.service --no-pager || echo "auditd.service is disabled"
fi
}
