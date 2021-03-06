# Built with arch: amd64 flavor: lxde image: ubuntu:18.04 localbuild: 1
#
################################################################################
# base system
################################################################################

FROM ubuntu:bionic as system

# built-in packages
ENV DEBIAN_FRONTEND noninteractive
RUN apt update \
    && apt install -y --no-install-recommends software-properties-common curl apache2-utils \
    && apt update \
    && apt install -y --no-install-recommends --allow-unauthenticated \
    supervisor nginx sudo net-tools zenity xz-utils \
    dbus-x11 x11-utils alsa-utils \
    mesa-utils libgl1-mesa-dri \
    && apt autoclean -y \
    && apt autoremove -y \
    && rm -rf /var/lib/apt/lists/*
# install debs error if combine together
RUN add-apt-repository -y ppa:fcwu-tw/apps \
    && apt update \
    && apt install -y --no-install-recommends --allow-unauthenticated \
    xvfb x11vnc=0.9.16-1 \
    vim-tiny firefox chromium-browser ttf-ubuntu-font-family ttf-wqy-zenhei  \
    && add-apt-repository -r ppa:fcwu-tw/apps \
    && apt autoclean -y \
    && apt autoremove -y \
    && rm -rf /var/lib/apt/lists/*

RUN apt update \
    && apt install -y --no-install-recommends --allow-unauthenticated \
    lxde gtk2-engines-murrine gnome-themes-standard gtk2-engines-pixbuf gtk2-engines-murrine arc-theme \
    && apt autoclean -y \
    && apt autoremove -y \
    && rm -rf /var/lib/apt/lists/*


# Additional packages require ~600MB
# libreoffice  pinta language-pack-zh-hant language-pack-gnome-zh-hant firefox-locale-zh-hant libreoffice-l10n-zh-tw

# tini for subreap
ARG TINI_VERSION=v0.18.0
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /bin/tini
RUN chmod +x /bin/tini

# ffmpeg
# RUN apt update \
#     && apt install -y --no-install-recommends --allow-unauthenticated \
#         ffmpeg \
#     && rm -rf /var/lib/apt/lists/* \
#     && mkdir /usr/local/ffmpeg \
#     && ln -s /usr/bin/ffmpeg /usr/local/ffmpeg/ffmpeg

# python library
COPY image/usr/local/lib/web/backend/requirements.txt /tmp/
RUN apt-get update \
    && dpkg-query -W -f='${Package}\n' > /tmp/a.txt \
    && apt-get install -y python-pip python-dev build-essential \
    && pip install setuptools wheel && pip install -r /tmp/requirements.txt \
    && dpkg-query -W -f='${Package}\n' > /tmp/b.txt \
    && apt-get remove -y `diff --changed-group-format='%>' --unchanged-group-format='' /tmp/a.txt /tmp/b.txt | xargs` \
    && apt-get autoclean -y \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /var/cache/apt/* /tmp/a.txt /tmp/b.txt


################################################################################
# builder
################################################################################
FROM ubuntu:18.04 as builder


RUN sed -i 's#http://archive.ubuntu.com/#http://tw.archive.ubuntu.com/#' /etc/apt/sources.list;


RUN apt-get update \
    && apt-get install -y --no-install-recommends curl ca-certificates gnupg patch

# nodejs
RUN curl -sL https://deb.nodesource.com/setup_8.x | bash - \
    && apt-get install -y nodejs

# yarn
RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - \
    && echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list \
    && apt-get update \
    && apt-get install -y yarn

# build frontend
COPY web /src/web
RUN cd /src/web \
    && yarn \
    && npm run build



################################################################################
# merge
################################################################################
FROM system
# LABEL maintainer="fcwu.tw@gmail.com"

COPY --from=builder /src/web/dist/ /usr/local/lib/web/frontend/

# Install QGIS

RUN apt update \
    && apt install -y \
    python3-pip \
    python3-dev \
    python3-setuptools \
    dirmngr \
    xterm \
    && apt autoclean \
    && apt autoremove \
    && rm -rf /var/lib/apt/lists/*

RUN echo "deb     http://qgis.org/ubuntu bionic main" >> /etc/apt/sources.list
RUN echo "deb-src http://qgis.org/ubuntu bionic main" >> /etc/apt/sources.list

RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-key CAEB3DC3BDF7FB45

RUN apt update && apt-get install -y qgis python3-qgis qgis-plugin-grass

COPY image /
EXPOSE 6080
WORKDIR /root
ENV HOME=/home/ubuntu \
    SHELL=/bin/bash

RUN groupadd --gid 816877 G-816877
RUN useradd --uid 458981 --create-home --shell /bin/bash --user-group --groups G-816877,adm,sudo ubuntu && chown ubuntu:G-816877 /home/ubuntu
RUN usermod -g G-816877 ubuntu
RUN mkdir -p /home/ubuntu/.config/pcmanfm/LXDE/ && cp /usr/local/share/doro-lxde-wallpapers/desktop-items-0.conf /home/ubuntu/.config/pcmanfm/LXDE/ && chown -R ubuntu:G-816877 /home/ubuntu/.config
COPY kill.py /
# COPY /etc/pki/tls/certs/designsafe-exec-01.tacc.utexas.edu.cer /etc/nginx/ssl/
# COPY /etc/pki/tls/private/designsafe-exec-01.tacc.utexas.edu.key /etc/nginx/ssl/
# HEALTHCHECK --interval=30s --timeout=5s CMD curl --fail http://127.0.0.1:6079/api/health
ENTRYPOINT ["/startup.sh"]