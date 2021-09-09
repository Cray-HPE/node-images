CephFS Provisioner
==================

See https://github.com/kubernetes-incubator/external-storage/tree/master/ceph/cephfs.

Known Limitations
-----------------

*   Kernel CephFS doesn't work with SELinux, setting SELinux label in Pod's
    securityContext will not work.

*   Kernel CephFS doesn't support quota or capacity, capacity requested by PVC
    is not enforced or validated.

*   Currently each Ceph user created by the provisioner has `allow r` MDS cap
    to permit CephFS mount.