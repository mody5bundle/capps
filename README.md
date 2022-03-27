## Why?

- restrict scope of file system access
- run any application without root privileges
- creates usable "Desktop applications" to integrate into your normal workflow
- cut network access for applications that work with confidential stuff to prevent accidental leakage
- set MEM and CPU boundaries for your applications (disclaimer: cpu limits not implemented yet)
- easy rollback with version pinning
- works on wayland

# Installation:

#### Tested and verified:

- [x] Fedora 35
- [ ] Ubuntu 21.10 #3

#### Fedora 35
```
pip install --user pyyaml
pip install --user jinja2
checkmodule -M -m -o capps.mod capps.te
semodule_package -o capps.pp -m capps.mod
sudo semodule -i capps.pp
./capps.py -a firefox -d
```

### Ubuntu 21.10

```
sudo apt install git python3 python3-pip podman
pip3 install jinja2
./capps.py -a sandbox -d
```

## Usage
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

## Example container that gets Created

```
podman run --rm -d --hostname firefox \
--name firefox-$RANDOM \
--cap-drop=ALL \
--read-only=true \
--read-only-tmpfs=false \
--systemd=false \
--userns=keep-id \
--security-opt=no-new-privileges \
--memory=2048mb \
--cap-add cap_sys_chroot \
--volume $HOME/Downloads/:/home/firefox/Downloads:rw \
--volume /run/user/$UID/pulse/native:/run/user/$UID/pulse/native:ro \
--volume $XDG_RUNTIME_DIR/$WAYLAND_DISPLAY:/tmp/$WAYLAND_DISPLAY:ro \
localhost/firefox
```



## Example config file for firefox
```
default_permissions: &default_permissions
  cap-drop: ALL
  read-only: true
  read-only-tmpfs: true
  systemd: false
  userns: keep-id
  security-opt: "no-new-privileges"
volumes:
  - &sound "/run/user/$UID/pulse/native:/run/user/$UID/pulse/native:ro"
  - &wayland "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY:/tmp/$WAYLAND_DISPLAY:ro"
  - &x11 /tmp/.X11-unix:/tmp/.X11-unix:ro
container:
  firefox:
    versioncmd: "firefox --version | awk \"'\"{print \\$3}\"'\""
    repo: "localhost"
    file: "firefox.dockerfile"
    path: "./container/firefox/"
    icon: "firefox.png"
    permissions:
      memory: 2048mb
      <<: *default_permissions
      read-only-tmpfs: false
      cap-add:
        - "cap_sys_chroot"
      volume:
        - "$HOME/Downloads/:/home/firefox/Downloads:rw"
        - *sound
        - *wayland
```


## list images

```
./capps.py -l
Available Containers in config:
firefox: 	Mem: 2048mb, 	Capabilities:  ['cap_sys_chroot'], 	cap-drop: ALL
Available images on host for firefox:
['localhost/firefox:latest', 'localhost/firefox:98.0']	Entrypoint: ['/bin/sh', '-c', '/usr/bin/firefox --private --private-window']	Size: 1178 MB	 	3391 Minutes old.
['localhost/firefox:97.0.1']	Entrypoint: ['/bin/sh', '-c', '/usr/bin/firefox --private --private-window']	Size: 1182 MB	 	26452 Minutes old.
['localhost/firefox:96.0']	Entrypoint: ['/bin/sh', '-c', '/usr/bin/firefox --private --private-window']	Size: 1156 MB	 	96024 Minutes old.
```

## get stats on started container

```
./capps.py -a firefox -s
NAME			MEM			  CPU	 READ/WRITE   PIDS
firefox-18685:	 232.1MB / 2.147GB / 10.81% 	 3.17% 	 -- / -- 57
firefox-18685:	 497.1MB / 2.147GB / 23.15% 	 2.24% 	 0B / 2.049MB 226
```

## Selinux:

```
cat capps.te
checkmodule -M -m -o capps.mod capps.te
semodule_package -o capps.pp -m capps.mod
semodule -i capps.pp
rm -rf capps.{pp,mod}
```
