# Docker for DOMjudge

[![Build and Publish DOMjudge](https://github.com/ItsNiklas/domjudge-docker/actions/workflows/docker-image.yml/badge.svg)](https://github.com/ItsNiklas/domjudge-docker/actions/workflows/docker-image.yml)

These Dockerfiles allow you to run [DOMjudge](https://www.domjudge.org) inside a
Docker container. For all further configuration needs and advanced guides,
see the [DOMjudge docs](https://www.domjudge.org/docs/manual/). The repository builds the latest nightly DOMjudge version daily and pushes it to [Docker Hub](https://hub.docker.com/r/itsniklas/).

## General

### Setup

Use [Docker Compose](https://docs.docker.com/compose/) to build the images:

    docker compose -f docker-compose-domserver.yml up -d
    docker compose -f docker-compose-judgehost.yml up -d

Swap out the docker `domjudge` images to fit your needs. To support custom executables, you need to rebuild the `judgehost` container, see below.
All environment variables can be set in the relevant `*.env` files.

### Building

The containers are built myself, the images are available on [Docker Hub](https://hub.docker.com/repositories/itsniklas).
You can build the containers yourself by taking a look at the [README](domjudge-packaging/docker/README.md).
The packaging scripts are based on the official [DOMjudge/domjudge-packaging](https://github.com/DOMjudge/domjudge-packaging) and [WISVCH/domjudge-packaging](https://github.com/WISVCH/domjudge-packaging) repositories.

## domserver

The domserver compose file comes bundled with a MariaDB container. If you want
to use this, you only need to specify a password for the mysql root user and for
the `domjudge` user by setting `MYSQL_ROOT_PASSWORD` to the root password, and
`MYSQL_PASSWORD` to the domjudge user password. It is also possible to specify
a database name and domjudge user name (both default to `domjudge`) by setting
`MYSQL_DATABASE` and `MYSQL_USER`.

The domserver and the MariaDB container are both configured to use volumes for
persistent storage. These can be found in the default `volumes` directory of docker.
The domserver volume just contains the webapp root, while the MariaDB volume
contains the whole database.

It is recommended to read this document carefully before starting the containers.

### Usage

The domserver will be available on port `12345` of the container host. You can
access the web interface on `/domjudge/` (e.g. `http://localhost:12345/domjudge/`).
To access the domserver from the internet, you need to set up your host to forward
the port to the container, e.g. using `nginx`.

### Domserver Configuration

Custom executables are provided in the `executables` directory. You can add them
using the web interface. In particular, `ghc` will have some problems with the default
configuration, so you will need to look at a custom executable.

Most of your configuration will be done in the web interface. You can log in
using the username `admin` and the password displayed in the logs of the
domserver container.

Go to the Config checker to verify that everything is set up correctly.

## MariaDB

If you need to, you can access the MariaDB by running:

    $ docker exec -it mariadb mariadb -u domjudge -pdjpw
    MariaDB [(none)]> USE domjudge;

or from the host:

    $ mariadb -h localhost -P 13306 -u domjudge -pdjpw
    MariaDB [(none)]> USE domjudge;

Version 8.3 also adds an Adminer container in the web interface to access the database.

### Upload limits

The custom built images have these limits set to 2GB by default!
Otherwise, to upload files larger than 256MB (e.g. large problem sets), use this to increase the limits in the fpm config:

    docker exec -it domserver sed -ri -e 's/(php_admin_value\[memory_limit\] =).*/\1 -1/' -e 's/(php_admin_value\[upload_max_filesize\] =).*/\1 2G/' -e 's/(php_admin_value\[post_max_size\] =).*/\1 2G/' /opt/domjudge/domserver/etc/domjudge-fpm.conf
    docker exec -it domserver supervisorctl restart php

Admittedly, this is a bit hacky, but it works and is better than rebuilding the container.

Also be sure to increase the `client_max_body_size` in your nginx config of the host server.

## judgehost

By default, four judgehosts are started. You can change this by modifying the
`docker-compose-judgehost.yml` file. You can also change the hostname of the
judgehosts. Each `judgedaemon` will be bound to one CPU core. You can change this
by modifying the `DAEMON_ID` environment variable.

### Requirements

As for the judgehost, you need to run the container in privileged mode to use
cgroups. You also need to specify the domserver URL and judgehost user password
by setting `DOMSERVER_HOST`, `JUDGEDAEMON_PASSWORD`. You can set `DOMJUDGE_USER`
as well, but it defaults to `judgehost`. You should also specify a hostname for
this container to identify it in the domserver.

Most importantly: You need to specify the following kernel parameters on the container host
to enable cgroups:

    cgroup_enable=memory swapaccount=1 systemd.unified_cgroup_hierarchy=0 isolcpus=2

This is done by editing `/etc/default/grub` and adding the parameters to `GRUB_CMDLINE_LINUX_DEFAULT`.
Then run `sudo update-grub` and reboot.

### Judgehost Configuration

The judgehost is based on `ubuntu:jammy`. If you want to support more programming languages, you need to edit
`install_languages.sh` inside the docker folder to enable, disable, add or update languages.
You can add arbitrary packages or PPAs to support more. Currently, the
script tries to install up-to-date versions of the languages, as of writing.

Enter the judgehost container and chroot to verify that everything is set up correctly:

    docker exec -it judgedaemonX /bin/bash
    docker exec -it judgedaemonX /opt/domjudge/judgehost/bin/dj_run_chroot

As of writing, the following languages are installed:

- Bash (GNU Bash 5.1)
- C (gcc 12.1 with C2X)
- C++ (gcc 12.1 with C++23)
- Haskell (GHC 8.8)
- Java (OpenJDK 19)
- JavaScript (Node.js 20.3 with ES2023)
- PyPy3 (7.3 with Python 3.9)
- Python3 (Python 3.11) (with numpy & scipy)
- Rust (Rust 1.65)

## Updating

To update the containers, fetch the latest images or change the version specified
in the compose file by running:

    docker compose -f docker-compose-domserver.yml pull
    docker compose -f docker-compose-judgehost.yml pull

Then run the setup from above (`up -d`) to recreate and restart the containers.
Fortunately, the files in the `volumes` directory are persistent, so you don't
need to worry about losing your data.

## Troubleshooting

If you have problems trying to run the containers, you can check the logs:

    docker logs domserver
    docker logs judgedaemonX

For more information, see the very helpful [DOMjudge docs](https://www.domjudge.org/docs/manual/),
try to find help in the source code, or ask me.

## Credits

This repository is based on [WISVCH/docker-domjudge](https://github.com/WISVCH/docker-domjudge) with aspects of [DOMjudge/domjudge](https://github.com/DOMjudge/domjudge/) and more.
