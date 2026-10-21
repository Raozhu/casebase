#!/bin/zsh
# Builds the site and publishes it to casebase.space (txcloud, /var/www/casebase).
# nginx config for the domain lives in /etc/nginx/conf.d/cvtool.conf on the server.
set -euo pipefail

SITE=${0:A:h}
$SITE/build.sh
rsync -az --delete --chmod=Du=rwx,Dgo=rx,Fu=rw,Fgo=r $SITE/dist/ txcloud:/var/www/casebase/
ssh txcloud 'chown -R root:root /var/www/casebase'
echo "https://casebase.space"
