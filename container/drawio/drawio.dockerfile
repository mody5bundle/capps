FROM registry.fedoraproject.org/fedora:latest
ARG USER
RUN dnf install -yq \
    libcanberra-gtk3 \
    PackageKit-gtk3-module \
    mesa-dri-drivers \
    wget \
    jq \
    libxshmfence \
    libdrm \
    mesa-libgbm \
    alsa-lib && \
    wget -q $(curl --silent "https://api.github.com/repos/jgraph/drawio-desktop/releases" | jq -r '.[0].assets[].browser_download_url' | grep x86_64.*.rpm) && \
    dnf install -y drawio-x86_64-*.rpm && rm -rf drawio-x86_64-*.rpm

# create group and user
RUN groupadd -g 1000 drawio && \
    # add user drawio to group drawio
    useradd -u 1000 -g 1000 drawio && \
    # create home directory
    mkdir -p /home/drawio && \
    chown 1000:1000 /home/drawio

USER 1000:1000

# set default directory
WORKDIR /home/drawio

# make sure firefox uses dark theme
ENV GTK_THEME=Adwaita:dark

# wayland
ENV WAYLAND_DISPLAY="wayland-0" DISPLAY=":0"

# XDG Variables
ENV XDG_SESSION_DESKTOP="gnome" XDG_CURRENT_DESKTOP="GNOME" XDG_RUNTIME_DIR=/tmp XDG_SESSION_TYPE=wayland


# no shm for X11
ENV QT_X11_NO_MITSHM=1

# make sure we set HOME
ENV HOME=/home/drawio

VOLUME /home/drawio/.config/draw.io/
VOLUME /home/drawio/.draw.io/

ENTRYPOINT /usr/bin/drawio

CMD /usr/bin/drawio
