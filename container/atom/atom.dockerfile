FROM registry.fedoraproject.org/fedora:latest
ARG USER
# install atom
RUN dnf install -yq --nodocs \
    # dependencies
    wget \
    gdk-pixbuf2 \
    gtk3-devel \
    alsa-lib-devel \
    libxkbfile \
    gvfs \
    trash-cli && \
    # download atom
    wget -q https://atom.io/download/rpm -O atom.x86_64.rpm && \
    # install atom and remove install file
    dnf install -yq --nodocs atom.x86_64.rpm && \
    dnf clean all && \
    rm -rf atom.x86_64.rpm && \
    find /usr/ | grep -E "(__pycache__|\.pyc|\.pyo$)" | xargs rm -rf

# user configuration
RUN groupadd -g $USER atom && \
    # add user atom to group atom
    useradd -u $USER -g $USER atom && \
    # create home directory
    mkdir -p /home/atom  && \
    chown -R $USER:$USER /home/atom

# gio-trash fix
RUN echo '#!/usr/bin/env bash' > /usr/local/bin/gvfs-trash && \
    echo '/usr/bin/trash-put "$@"' >> /usr/local/bin/gvfs-trash && \
    chmod +x /usr/local/bin/gvfs-trash

# set default directory
WORKDIR /home/atom

# change user
USER $USER:$USER

RUN apm install gtk-dark-theme && \
  # set global theme to dark
  gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark'

# make sure we set HOME
ENV HOME=/home/atom

# make sure firefox uses dark theme
ENV GTK_THEME=Adwaita:dark

# wayland
ENV WAYLAND_DISPLAY="wayland-0" DISPLAY=":0"

# XDG Variables
ENV XDG_SESSION_DESKTOP="gnome" XDG_CURRENT_DESKTOP="GNOME" XDG_RUNTIME_DIR=/tmp XDG_SESSION_TYPE=wayland

# use trash-cli because gio doesnt support mounted volumes?!
ENV ELECTRON_TRASH=gvfs-trash

# no shm for X11
ENV QT_X11_NO_MITSHM=1

# script to run and wait for atom
ENTRYPOINT /usr/bin/atom --no-xshm --in-process-gpu --wait --new-window /workdir
