virtinst scripts
================

virt-install script with RHEL (CentOS) kickstart and Debian (Ubuntu) preseed

Ubuntu (Debian)
---------------

```
ubuntu-virtinst-preseed.sh NAME RELEASE [i386|amd64]
```

* RELEASE should be either of Ubuntu code name (e.g., precise, raring, trusty)
* (optional) CPU architecture can be specified. Default is ``amd64``.

```
ubuntu-virtinst.sh NAME RELEASE
```
This script just calls virt-install. No preseed config is specified,
so all installation options need to be specified as usual installation.

CentOS (RHEL)
-------------

```
centos-virtinst-kickstart.sh NAME RELEASE
```

* RELEASE should be either of CentOS release version (e.g., 6, 6.5, 6.4)
