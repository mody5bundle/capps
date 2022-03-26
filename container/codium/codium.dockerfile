FROM fedora:latest
ARG USER
RUN dnf install -yq wget jq && \
    wget -q $(curl --silent "https://api.github.com/repos/VSCodium/vscodium/releases" | jq -r '.[0].assets[].browser_download_url' | grep x86_64.rpm) && \
    sha256sum -c codium-*.rpm.sha256 && \
    dnf install -yq \
    codium-*.rpm \
    libxshmfence \
    libcanberra-gtk3 \
    PackageKit-gtk3-module \
    mesa-dri-drivers \
    libglvnd-glx \
    pylint \
    python3-pyyaml \
    python3-ansible-lint \
    python3-jinja2 \
    black \
    git && \
    rm -rf codium-*.rpm.*

# user configuration
# create group and user
RUN groupadd -g $USER codium && \
    # add user codium to group codium
    useradd -u $USER -g $USER codium && \
    # create home directory
    mkdir -p /home/codium && \
    chown $USER:$USER /home/codium

# set default directory
WORKDIR /home/codium

COPY settings.json /home/codium/.config/VSCodium/User/settings.json

RUN chown -R $USER:$USER /home/codium/.*

# change user
USER $USER:$USER

# install extenstions and get ansible json schemas
RUN codium --install-extension ms-python.python && \
    codium --install-extension redhat.vscode-yaml && \
    codium --install-extension redhat.vscode-xml && \
    # codium --install-extension ms-azuretools.vscode-docker && \
    # codium --install-extension eamodio.gitlens && \
    mkdir -p ~/.config/VSCodium/json/ && \
    wget -q -O ~/.config/VSCodium/json/ansible-tasks.json https://raw.githubusercontent.com/ansible-community/schemas/main/f/ansible-tasks.json && \
    wget -q -O ~/.config/VSCodium/json/ansible-vars.json https://raw.githubusercontent.com/ansible-community/schemas/main/f/ansible-vars.json && \
    wget -q -O ~/.config/VSCodium/json/ansible-playbook.json https://raw.githubusercontent.com/ansible-community/schemas/main/f/ansible-playbook.json

# use dark theme and add buttons to window bar
#RUN gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark' && \
#    gsettings set org.gnome.desktop.wm.preferences button-layout ':minimize,maximize,close'

# make sure we set HOME
ENV HOME=/home/codium

# make sure codium uses dark theme
ENV GTK_THEME=Adwaita:dark

# wayland
ENV WAYLAND_DISPLAY="wayland-0" DISPLAY=":0"

# XDG Variables
ENV XDG_SESSION_DESKTOP="gnome" XDG_CURRENT_DESKTOP="GNOME" XDG_RUNTIME_DIR=/run/user/$USER XDG_SESSION_TYPE=wayland XDG_CONFIG_HOME=/home/codium/.config

# no shm for X11
ENV QT_X11_NO_MITSHM=1

# create volumes
VOLUME /home/codium/.vscode-oss
VOLUME /home/codium/.config/VSCodium

ENTRYPOINT /usr/bin/codium --verbose --wait -n  /home/codium/workdir/
