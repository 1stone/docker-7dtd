FROM ubuntu

#### Labels ####
LABEL maintainer="1stone"

ARG USER=sdtd \
    HOME=/home/sdtd

# Run as a non-root user by default
ARG PGID=1000 \
    PUID=1000

# Insert Steam prompt answers
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN echo steam steam/question select "I AGREE" | debconf-set-selections \
 && echo steam steam/license note '' | debconf-set-selections

#### Install Packages ####
RUN --mount=type=cache,target=/var/cache/apt \
    DEBIAN_FRONTEND=noninteractive \
    dpkg --add-architecture i386 \
 && apt update -y \
 && apt install -y --no-install-recommends \
      curl \
      bzip2 \
      less \
      gzip \
      unzip \
      rsync \
      ca-certificates \
      telnet \
      expect \
      locales \
      steamcmd \
      lib32gcc-s1 \
      cron \
      sudo \
      vim \
      xmlstarlet \
 && apt clean \
 && rm -rf /tmp/* /var/lib/apt/lists/* /var/tmp/*

# Add unicode support
RUN locale-gen en_US.UTF-8
ENV LANG='en_US.UTF-8'
ENV LANGUAGE='en_US:en'

# Create symlink for steamcmd
RUN ln -s /usr/games/steamcmd /usr/bin/steamcmd

# Set working directory
RUN adduser --disabled-password \
            --shell /bin/bash \
            --disabled-login \
            --gecos "" \
            --home $HOME \
            $USER \
 && echo "$USER ALL = NOPASSWD: /etc/init.d/cron, /usr/bin/chown -R sdtd\:sdtd $HOME"  > /etc/sudoers.d/sdtd

# Add files
COPY --chmod=755 scripts /scripts

WORKDIR $HOME
USER $USER

# SDTD Configuration
ENV SDTD_APP_DIR=$HOME/serverfiles \
    SDTD_CFG_UserDataFolder=$HOME/userdata \
    SDTD_CFG_SaveGameFolder=$HOME/saves \
    SDTD_STARTUP_ARGUMENTS="-quit -batchmode -nographics -dedicated"

# Expose necessary ports
EXPOSE 26900/tcp \
       26900/udp \
       26901/udp \
       26902/udp \
       26903/udp \
       8080/tcp

VOLUME $HOME

ENTRYPOINT ["/scripts/startup.sh"]
