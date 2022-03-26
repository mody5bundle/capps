# Why?

- restrict scope of file system access
- run any application without root privileges
- creates usable "Desktop applications" to integrate into your normal workflow
- cut network access for applications that work with confidential stuff to prevent accidental leakage
- set MEM and CPU boundaries for your applications (disclaimer: cpu limits not implemented yet)
- easy rollback with version pinning
- works on wayland


# Usage
```
capps.py [-h] [-a app1 app2 ... [app1 app2 ... ...]] [-c /path/to/config.yaml] [-b] [-r] [-i] [-v] [-s] [-d] [-l]

Start podman container apps.

options:
  -h, --help            show this help message and exit
  -a app1 app2 ... [app1 app2 ... ...], --application-list app1 app2 ... [app1 app2 ... ...]
                        List of applications to run as defined in config file
  -c /path/to/config.yaml, --config /path/to/config.yaml
                        Path to config file (defaults to config.yaml)
  -b, --build           (re)build list of provided apps
  -r, --run             run containers of all provided apps (default)
  -i, --install         install as desktop application
  -v, --verbose         enable verbose log output
  -s, --stats           enable stats output
  -d, --debug           enable debug log output
  -l, --list            print available container
```

## Selinux:

```
cat capps.te
checkmodule -M -m -o capps.mod capps.te
semodule_package -o capps.pp -m capps.mod
semodule -i capps.pp
rm -rf capps.{pp,mod}
```
