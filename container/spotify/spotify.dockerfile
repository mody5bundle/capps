# use debian as base image
FROM docker.io/library/debian:latest
ARG USER
# install dependencies
RUN apt-get update && apt-get install --no-install-recommends -y libsm6 dbus-x11 curl ca-certificates gnupg2 libpulse0 libasound2 libx11-xcb1 libcanberra-gtk-module libcanberra-gtk3-module 2>&1 > /dev/null && \
    # add spotify public key
    curl -sS https://download.spotify.com/debian/pubkey_5E3C45D7B312C643.gpg | apt-key add - 2>&1 > /dev/null && \
    # add spotify repository
    echo "deb http://repository.spotify.com stable non-free" > /etc/apt/sources.list.d/spotify.list && \
    # install spotify
    apt-get update && apt-get install --no-install-recommends -y spotify-client 2>&1 > /dev/null && \
    # add group for user
    groupadd -g $USER spotify && \
    # add user spotify to group spotify
    useradd -u $USER -g $USER spotify && \
    # create home directory
    mkdir -p /home/spotify && \
    chown -R $USER:$USER /home/spotify && \
    # cleanup
    apt-get remove -y ca-certificates gnupg2 curl perl && apt-get clean autoclean && apt-get autoremove --purge --yes && \
    bash -c 'rm -rf /usr/share/{icons,doc/libunistring2,doc,locale,man,mime,zoneinfo/*/Indian,zoneinfo} /var/lib/{apt,dpkg,cache,log} /var/{cache,log} /lib/systemd /usr/bin/{systemd-analyze,perl}'

# set default directory
WORKDIR /home/spotify
ENV HOME=/home/spotify
USER $USER:$USER

# wayland
ENV WAYLAND_DISPLAY="wayland-0" DISPLAY=":0"

# XDG Variables
ENV XDG_SESSION_DESKTOP="gnome" XDG_CURRENT_DESKTOP="GNOME" XDG_RUNTIME_DIR=/run/user/$USER XDG_SESSION_TYPE=wayland

# no shm for X11
ENV QT_X11_NO_MITSHM=1

# Pulse socket
ENV PULSE_SERVER="unix:/run/user/$USER/pulse/native"

VOLUME /home/spotify/.cache/spotify/
VOLUME /home/spotify/.config/spotify/
VOLUME /var/log/
VOLUME /run/user/$USER

ENTRYPOINT /usr/bin/spotify --verbose --show-console
