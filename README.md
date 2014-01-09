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

CentOS (RHEL)
-------------

```
centos-virtinst-kickstart.sh NAME [RELEASE [i386|x86_64]]
```

* RELEASE should be either of CentOS release version (e.g., 6, 6.5, 6.4)
