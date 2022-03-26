FROM registry.fedoraproject.org/fedora:latest
ARG USER
RUN dnf install -y \
    libcanberra-gtk3 \
    PackageKit-gtk3-module \
    mesa-dri-drivers \
    bash \
    gnome-terminal \
    dbus-x11 \
    glibc-all-langpacks \
    gawk

RUN groupadd -g $USER bash && \
    # add user bash to group bash
    useradd -u $USER -g $USER -G wheel bash && \
    # create home directory
    mkdir -p /home/bash && \
    chown $USER:$USER /home/bash && \
    # nopasswd for sudo
    sed -i 's/%wheel\tALL=(ALL)\tALL/%wheel\tALL=(ALL)\tNOPASSWD: ALL/g' /etc/sudoers

USER $USER:$USER

RUN gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark'

ENV LANG="en_US.UTF-8" DESKTOP_STARTUP_ID="0"

# wayland
ENV WAYLAND_DISPLAY="wayland-0" DISPLAY=":0"

# make sure gtk uses dark theme
ENV GTK_THEME=Adwaita:dark

# XDG Variables
ENV XDG_SESSION_DESKTOP="gnome" XDG_CURRENT_DESKTOP="GNOME" XDG_RUNTIME_DIR=/tmp XDG_SESSION_TYPE=wayland

# set default directory
WORKDIR /home/bash

ENTRYPOINT gnome-terminal --wait -v
