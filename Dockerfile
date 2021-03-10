FROM ubuntu

#### Labels ####
LABEL maintainer="1stone"

ENV USER=sdtd \
    HOME=/home/sdtd

# Run as a non-root user by default
ENV PGID=1000 \
    PUID=1000

#### Runtime Environment ####
ENV VERSION_SDTD=7919985 \
    VERSION_ILLY=v22_24_39

# Set working directory
RUN adduser --disabled-password --shell /bin/bash --disabled-login --gecos "" sdtd
WORKDIR $HOME

# Insert Steam prompt answers
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN echo steam steam/question select "I AGREE" | debconf-set-selections \
 && echo steam steam/license note '' | debconf-set-selections

#### Install Packages ####
ARG DEBIAN_FRONTEND=noninteractive
RUN dpkg --add-architecture i386 \
 && apt update -y \
 && apt install -y --no-install-recommends \
      curl \
      bzip2 \
      gzip \
      unzip \
      rsync \
      ca-certificates \
      telnet \
      expect \
      locales \
      steamcmd \
      cron \
      gosu \
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

# Update SteamCMD and verify latest version
RUN steamcmd +quit

# Add files
COPY build /

# SDTD Configuration
ENV SDTD_CFG_UserDataFolder=/home/sdtd/data \
    SDTD_CFG_SaveGameFolder=/home/sdtd/instance \
    SDTD_STARTUP_ARGUMENTS="-quit -batchmode -nographics -dedicated"

# Apply owner & permissions
RUN find /scripts -type f -iname "*.sh" -exec chmod +x {} \;

# Expose necessary ports
EXPOSE 26900/tcp \
       26900/udp \
       26901/udp \
       26902/udp \
       26903/udp \
       8080/tcp \
       8081/tcp \
       8082/tcp

VOLUME /home/sdtd
ENTRYPOINT ["/launcher.sh", "/scripts/startup.sh"]
