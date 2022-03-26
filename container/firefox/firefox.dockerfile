# use latest fedora image as base
FROM registry.fedoraproject.org/fedora:latest
ARG USER
# install firefox
RUN dnf install -y \
    firefox \
    mozilla-ublock-origin \
    mozilla-https-everywhere \
    mozilla-noscript \
#    mozilla-privacy-badger \
    libcanberra-gtk3 \
    PackageKit-gtk3-module \
    mesa-dri-drivers \
    gsettings-desktop-schemas

# user configuration
# create group and user
RUN groupadd -g $USER firefox && \
    # add user firefox to group firefox
    useradd -u $USER -g $USER firefox && \
    # create home directory
    mkdir -p /home/firefox && \
    chown $USER:$USER /home/firefox

# set default directory
WORKDIR /home/firefox

# change user
USER $USER:$USER

# use dark theme and add buttons to window bar
RUN gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark' && \
    gsettings set org.gnome.desktop.wm.preferences button-layout ':minimize,maximize,close'

# make sure we set HOME
ENV HOME=/home/firefox

COPY user.js /home/firefox/user.js

# create profile and add config
RUN firefox --headless --first-startup --screenshot about:about /dev/null && \
    mv /home/firefox/user.js $(echo  ~/.mozilla/firefox/*.default-release)/user.js

# create volumes so we can run with --read-only
VOLUME /home/firefox/.mozilla/
VOLUME /home/firefox/Downloads/
VOLUME /home/firefox/.cache/mozilla/firefox/
VOLUME /home/firefox/.cache/fontconfig/
VOLUME /tmp/dconf/

# make sure firefox uses dark theme
ENV GTK_THEME=Adwaita:dark

# wayland
ENV WAYLAND_DISPLAY="wayland-0" DISPLAY=":0"

# XDG Variables
ENV XDG_SESSION_DESKTOP="gnome" XDG_CURRENT_DESKTOP="GNOME" XDG_RUNTIME_DIR=/tmp XDG_SESSION_TYPE=wayland

# no shm for X11
ENV QT_X11_NO_MITSHM=1

# Pulse socket
ENV PULSE_SERVER="unix:/run/user/$USER/pulse/native"

ENTRYPOINT /usr/bin/firefox --private --private-window
