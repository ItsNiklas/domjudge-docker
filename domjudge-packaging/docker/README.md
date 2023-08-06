# DOMjudge Docker containers

This directory contains the necessary files to create Docker images which can be used to run DOMjudge.

There is one container for running the domserver and one for running a judgehost.

The domserver container contains:

* A setup script that will:
    * Set up or update the database.
    * Set up the webserver.
* PHP-FPM and nginx for running the web interface.
* Scripts for reading the log files of the webserver.

The judgehost container contains a working judgehost with cgroup support and a chroot for running the submissions.

These containers do not include MySQL / MariaDB; the [MariaDB](https://hub.docker.com/r/_/mariadb/) Docker container does this better than we ever could.

## Using the images

These images are available on the [Docker Hub](https://hub.docker.com) as `domjudge/domserver` and `domjudge/judgehost`.
Custom daily builds are located at `itsniklas/domjudge-domserver-nightly` and `itsniklas/domjudge-judgehost-nightly`.

Images created from this repository are automatically built every night and pushed to the Docker Hub.

## Building the images

If you want to build the images yourself, you can just run

```bash
  ./build.sh version
```

where `version` is the DOMjudge version to create the images for, e.g. `8.2.0`.

To build domjudge with local sources, run
```bash
  ./build-domjudge.sh [docker-tag]
  ./build-judgehost.sh [docker-tag]
```
Note that the source directory name has to match `domjudge`.

## Customizing the image

The images in this repository are already customized to a certain extent. Most importantly, they install custom language runtimes for the judgehost in `install_languages.sh`.

### Domjudge

The image initializes itself with the `start.sh` script.
This script runs all executable files in `/scripts/start.d/` in alphabetical order.
Before that, all files from `/scripts/start.ro/` are copied into the `start.d` folder.
To customize any settings (e.g. modify the nginx config), add scripts to `start.ro` via a bind mount.

*Warning*: The scripts inside this folder have full access to everything in the container (including passwords etc.).
Only run trusted code there.

To enable `REMOTE_USER` processing provided by a proxy in front of this image, mount the scripts from `examples/remote_user_scripts` to `start.ro`.

### Judgehost

To customize the packages available in the chroot (e.g. runtimes needed for submission languages), modify the `judgehost/chroot-and-tar.sh`, adding `-i <comma separated list of packages>` to the `dj_make_chroot` call.
