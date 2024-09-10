#!/bin/sh -eu

cd /domjudge-src/domjudge*
chown -R domjudge: .
# If we used a local source tarball, it might not have been built yet
sudo -u domjudge sh -c '. /venv/bin/activate && make dist'
sudo -u domjudge ./configure

# Passwords should not be included in the built image. We create empty files here to prevent passwords from being generated.
sudo -u domjudge touch etc/dbpasswords.secret etc/restapi.secret etc/symfony_app.secret etc/initial_admin_password.secret

sudo -u domjudge make domserver
make install-domserver

# Remove installed password files
rm /opt/domjudge/domserver/etc/*.secret

sudo -u domjudge sh -c '. /venv/bin/activate && make docs'
# Use venv to use latest Sphinx. 6.1.0 or higher is required to build DOMjudge docs.
# shellcheck source=/dev/null
. /venv/bin/activate
make install-docs
