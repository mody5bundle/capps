FROM registry.fedoraproject.org/fedora:latest
ARG USER
RUN dnf install -y \
    libcanberra-gtk3 \
    PackageKit-gtk3-module \
    mesa-dri-drivers

# install vlc
RUN dnf install -y \
    https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
    https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm \
    libcanberra-gtk3 \
    PackageKit-gtk3-module \
    mesa-dri-drivers && \
    dnf install -y vlc nautilus samba-client && \
    rm -rf /var/cache/

# create group and user
RUN groupadd -g $USER vlc && \
    # add user vlc to group vlc
    useradd -u $USER -g $USER vlc && \
    # create home directory
    mkdir -p /home/vlc && \
    chown $USER:$USER /home/vlc

# change user
USER $USER:$USER

# set default directory
WORKDIR /home/vlc

RUN gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark'

# make sure we set HOME
ENV HOME=/home/vlc

# create volumes so we can run with --read-only
VOLUME /home/vlc/.cache
VOLUME /home/vlc/.local/share

# make sure vlc uses dark theme
ENV GTK_THEME=Adwaita:dark

# wayland
ENV WAYLAND_DISPLAY="wayland-0" DISPLAY=":0"

# XDG Variables
ENV XDG_SESSION_DESKTOP="gnome" XDG_CURRENT_DESKTOP="GNOME" XDG_RUNTIME_DIR=/tmp XDG_SESSION_TYPE=wayland

# no shm for X11
ENV QT_X11_NO_MITSHM=1

# Pulse socket
ENV PULSE_SERVER="unix:/run/user/$USER/pulse/native"

ENTRYPOINT /usr/bin/vlc
