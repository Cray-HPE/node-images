#!/usr/bin/env bash


rgw_vip_ip=$(craysys metadata get rgw_virtual_ip)

echo "# Please do not change this file directly since it is managed by Ansible and will be overwritten
! Configuration File for keepalived

global_defs {
   router_id CEPH_RGW
}

vrrp_script check_haproxy {
    script \"killall -0 haproxy\"
    weight -20
    interval 2
    rise 2
    fall 2
}

vrrp_instance VI_0 {
    state BACKUP
    priority 90
    interface vlan002
    virtual_router_id 51
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass 1234
    }
    virtual_ipaddress {
        "$rgw_vip_ip"/17 dev vlan002
    }
    track_script {
        check_haproxy
    }
}"
