# [1stone/7dtd-server](https://github.com/1stone/docker-7dtd)

![Image of 7 Days To Die](https://raw.githubusercontent.com/1stone/docker-7dtd/master/7dtd.png)


## Information
This project creates a docker container to host a 7 Days To Die Server (7DTD) instance.

Some design principles:

- A docker container uses distinct versions for all components. These are either  taken as defaults from the docker image as defined during build, or can be  overridden during startup. There is deliberatly **no** update mechanism within the image, which performs automatic updates to the 7DTD server or accompanied components. See section "Upgrades".
- The container gathers and installs all required components during initialization. In particular:
  - Download and install 7DTD Server via SteamCMD
  - Optionally, download and install Alloc Fixes Mod.
- The container runs non-root, makeing public operation as secure as possible.
- All variable components are installed into a single base dir, which is placed into a docker volume.
  This prevents the time-consuming initialization process on each restart.
- There shall be no need to provide or alter configuration files directly. Any configuration of `serverconfig.xml` or `serveradmin.xml` can be provided through environment variables (see below).
- A container holds a single 7DTD instance. For multiple instances use distinct containers.


## Build
The docker image is independent of a particular 7DTD version and should work with
any version you desire. However, the `Dockerfile` provides version defaults for
all components, which should represent a working combination of the lastest
"stable" release. See section "Usage" for more information.

Building the docker image is as simple as
```bash
docker build -t 1stone/7dtd-server .
```
Or directly via docker-compose:
```bash
docker compose build
```

### Container Layout
The container is based on a minimal [Ubuntu image](https://hub.docker.com/_/ubuntu) and is kept as lean as possible.
All required OS runtime components are downloaded and installed through APT and are provided through the container image.
On container intitialization, all volatile data is placed below `/home/sdtd`. Than includes
- SteamCmd data in `/home/sdtd/.steam`
- 7DTD Server Installation in `/home/sdtd/serverfiles`
- 7DTD *SavegameFolder* in `/home/sdtd/saves`
- 7DTD *UserDataFolder* in `/home/sdtd/userdata`
- Backups in `/home/sdtd/backups`

All of above is kept persistent throughout container restarts by using a docker volume for `/home/sdtd`.

### Effective User-/Group-ID
By default, the container uses 1000:1000 as the effective UID:GID for running the unprivileged processes and creating files.
To adjust this to your particular hosting environment, use the build arguments PUID and PGID as shown below:

|Build-Arg | Value | Note |
|-------------|-------|------|
|`PUID`|`{uid}`|Set effective UID to "uid".|
|`PGID`|`{gid}`|Set effective GID to "gid".|


## Usage
General operation of the docker image is as follows:
- Upon first run, a new docker volume is created and mounted at `/home/sdtd`.
- If the installed versions for *7DTD* and *Alloc Mod Fixes* do not match the previous versions recorded in `/home/sdtd/.versions`, they are downloaded and installed.
- Configuration settings provided through the docker environment are applied.
- Optional cron-jobs (e.g. for periodic backups) are installed.
- 7DTD server is started.
- Any INT oder TERM signals are watched, to shutdown the server gracefully.

### Runtime Parameters
A major design principle was to eliminate the need for pre-crafted or post-modified configuration files. Therefore most of the required configuration - if not all - can be provided through environment variables provided through the docker context.

#### Using explicit versions
When running the image, you must tell the executing container which 7DTD version to use by setting the variable `VERSION_SDTD`.
If this version differs from the last run, a new 7DTD release is installed during startup.

The same mechanism applies for the AllocMod extension, by setting `VERSION_ILLY` to the particular version.
NOTE: Starting with 7DTD version Alpha-21, a lot of functionality from that mod has been integrated into 7DTD already. Please check, if you still require it.

Configuration-Schema:

|Env-Variable | Value | Note |
|-------------|-------|------|
|`VERSION_SDTD`|`{version}`| Specify branch name or build id|
|`VERSION_ILLY`|`{version}`| Specify version of server fixes|

Version information can be found for
- 7DTD at https://steamdb.info/app/294420/depots/
- Alloc Fixes Mod at https://7dtd.illy.bz/wiki/Server%20fixes

#### 7DTD Server Configuration
Configuration of the 7DTD server is usually done in `serverconfig.xml`.
While it is still possible to provide a fully pre-crafted file, or modify the default file after first initialization, basically all server configuration can also be done via docker environment variables.

An environment variable prefixed with `SDTD_CFG_` sets the particular configuration value in `serverconfig.xml`.

Configuration-Schema:

|Env-Variable | Value | Note |
|-------------|-------|------|
|`SDTD_CFG_{property}`|`{value}`|Generic `serverconfig.xml` assignment to set "property" to "value".|

#### 7DTD Admin Configuration
The configuration of 7DTD's `serveradmin.xml` can be provided accordingly.
Either by changing the default file in the intialized docker volume, or via specific environment values prefixed with `SDTD_ADMIN_`.

Configuration-Schema:

|Env-Variable | Value | Note |
|-------------|-------|------|
|`SDTD_ADMIN_USER_{userid}`|`{name}:{level}`|Declare a new user entry for ID "userid", having a human-readable "name" to permission "level".|
|`SDTD_ADMIN_GROUP_{groupid}`|`{name}:{level}:{mod}`| Declare a new group entry for ID "groupid", with "name", "level" and "mod" permissions.|
|`SDTD_ADMIN_PERMISSION_{command}`|`{level}`|Define the permission "level" for a particular "command".|

#### Backup
Regular backups of the *SaveGameFolder* can be performed automatically.

Configuration-Schema:

|Env-Variable | Value | Note |
|-------------|-------|------|
|`BACKUP_DIR`|`{directory}`|(optional) - defaults to `/home/sdtd/backups`.|
|`BACKUP_MAXNUMBER`|`{number}`|Limit maximum backups to "number".|
|`BACKUP_COMPRESS`|`(none|old|all)`|Define which backups should be compressed into a tar.bz2 file.|
|`BACKUP_SCHEDULE`|`{cronspec}`|Define the cronjob interval, when to perform backups (e.g. `*/15 * * * *` for each 15min).|

### Ports
The container uses the following ports:

|Port | Service |
|-----|---------|
|26900/tcp|Game details query port|
|26900/udp|Steam's master server list interface|
|26901/udp|Steam communication|
|26902/udp|Networking via RakNet|
|26903/udp|Networking via UNET|
|8080/tcp|Web control panel|
|8081/tcp|Telnet control interface|
|8082/tcp|Web panel of Alloc Mod|

Expose them as required in your docker environment.


## Examples
The following examples should give some ideas how to run this container.
Adjust this to your particular requirement or environment as appropriate.

### with Docker

The following command starts a new container "7dtdserver" from the previously build image.
It ...

- maps the docker volume for `/home/sdtd` to a local directory `data`, to allow post-initialization modifications to the 7DTD configuration
- provides some basic 7DTD server configuration
- entitles the SteamID 4578623497632 full administration rights (level 0)
- explicitly sets some command level permissions
- exposes some ports - partly diverting to avoid conflicts with other servies on the host - but keeping the telnet port internal to the container
- enables a periodic backup on each full hour, 24x7

```bash
docker run \
  --name 7dtdserver \
  -v "./data:/home/sdtd" \
  -e VERSION_SDTD=11589588 \
  -e SDTD_CFG_ServerName=Test-Server \
  -e SDTD_CFG_ServerPassword=2secret4you \
  -e SDTD_CFG_ControlPanelEnabled=true \
  -e SDTD_CFG_ControlPanelPassword=2secret4you \
  -e SDTD_CFG_TelnetEnabled=true \
  -e SDTD_ADMIN_USER_45786234976322364=Dummy User:0 \
  -e SDTD_ADMIN_PERMISSION_say=1 \
  -e SDTD_ADMIN_PERMISSION_dm=0 \
  -e SDTD_ADMIN_PERMISSION_memcl=100 \
  -e BACKUP_DIR=/home/sdtd/backups \
  -e BACKUP_MAXNUMBER=5 \
  -e BACKUP_COMPRESS=old \
  -e BACKUP_SCHEDULE=0 * * * * \
  -p 26900:26900/tcp \
  -p 26900:26900/udp \
  -p 26901:26901/udp \
  -p 26902:26902/udp \
  -p 26903:26903/udp \
  -p 18080:8080/udp \
  -p 18082:8082/tcp \
  ghcr.io/1stone/docker-7dtd:latest
```

### with docker-compose
The same configuration from the manual docker invocation as defined through a `docker-compose.yml` file:

```yaml
version: '2'
services:
  7dtdserver:
    image: ghcr.io/1stone/docker-7dtd:latest
    environment:
      # 7DTD Version to use (see https://steamdb.info/app/294420/depots/)
      - VERSION_SDTD=11589588

      # Uncomment to apply AllocMod Extension
      #- VERSION_ILLY=v24_29_42

      # Server-Config settings
      - SDTD_CFG_ServerName=my-server-name
      - SDTD_CFG_ServerDescription=my-server-name-description
      - SDTD_CFG_ServerPassword=my-very-secret-password
      - SDTD_CFG_GameWorld=RWG
      - SDTD_CFG_WorldGenSeed=my-rwg-seed
      - SDTD_CFG_WorldGenSize=6144
      - SDTD_CFG_BloodMoonEnemyCount=16
      - SDTD_CFG_GameName=my-game-name
      - SDTD_CFG_DayNightLength=90
      - SDTD_CFG_DropOnDeath=3

      # Admin Settings
      - SDTD_ADMIN_USER_${MY_EOS_ADMIN_ID}=${MY_USER_NAME}:0
      - SDTD_ADMIN_GROUP_103582791434672565=Steam Universe:1000:0
      - SDTD_ADMIN_PERMISSION_say=1
      - SDTD_ADMIN_PERMISSION_dm=0
      - SDTD_ADMIN_PERMISSION_memcl=100

      # Automatic Backup Settings
      - BACKUP_DIR=/home/sdtd/backups
      - BACKUP_MAXNUMBER=5
      - BACKUP_COMPRESS=none
      - BACKUP_SCHEDULE=*/15 * * * *

      # Prevent any core images on crash
      - RLIMIT_CORE=0

    ports:
      - "26900:26900"
      - "26900:26900/udp"
      - "26901:26901/udp"
      - "26902:26902/udp"
      - "26903:26903/udp"
      - "8080:8080"

    volumes:
      - ./data:/home/sdtd
```


## Support Info
- Shell access whilst the container is running: `docker exec -it -u sdtd 7dtdserver /bin/bash`
- Monitor the logs of the container in realtime: `docker logs -f 7dtdserver`
- Get current versions used in the container: `docker exec -it -u sdtd 7dtdserver cat .versions`
- Perform manual backup: `docker exec -it -u sdtd 7dtdserver /scripts/backup.sh`


## Updating Info
The docker image runs exactly with the version you specify with `VERSION_SDTD`, even when newer versions are avaiable on Steam.
Thus, no autoamtic upgrade or whatsoever is performed during restart.

New docker images are provided through the Github registry as fixes or improvements are implemented.
To update existing containers, the usual procedures for docker and docker-compose apply.

