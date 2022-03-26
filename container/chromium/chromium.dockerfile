# use debian as base image
ARG USER
FROM docker.io/library/fedora:latest

# install dependencies
RUN dnf install -y chromium libcanberra-gtk3 \
				PackageKit-gtk3-module \
				mesa-dri-drivers \
				gsettings-desktop-schemas

# set default directory
WORKDIR /home/chromium
ENV HOME=/home/chromium
USER $USER:$USER

# wayland
ENV WAYLAND_DISPLAY="wayland-0" DISPLAY=":0"

# XDG Variables
ENV XDG_SESSION_DESKTOP="gnome" XDG_CURRENT_DESKTOP="GNOME" XDG_RUNTIME_DIR=/tmp XDG_SESSION_TYPE=wayland

# no shm for X11
ENV QT_X11_NO_MITSHM=1

# Pulse socket
ENV PULSE_SERVER="unix:/run/user/$USER/pulse/native"

VOLUME /home/chromium/.cache/chromium/
VOLUME /home/chromium/.config/chromium/
VOLUME /var/log/

ENTRYPOINT /usr/bin/chromium-browser --in-process-gpu --no-sandbox --verbose --show-console
