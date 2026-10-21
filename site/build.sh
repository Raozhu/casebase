#!/bin/zsh
# Assembles casebase.space into site/dist: the page, the live HTML demos,
# the round-table videos, icons and the installer.
set -euo pipefail

SITE=${0:A:h}
ROOT=${SITE:h}
DIST=$SITE/dist
DEMOS=$ROOT/tools/readme-demos/web
MEDIA=$ROOT/build/readme-demos/web
VERSION=0.1.0

rm -rf $DIST
mkdir -p $DIST/assets $DIST/demos/assets $DIST/media $DIST/downloads
cp $SITE/index.html $SITE/site.css $SITE/site.js $DIST/
cp $DEMOS/{demo.html,demo.css,demo.js,engine.js,icons.js} $DIST/demos/
cp $DEMOS/assets/*.png $DIST/demos/assets/
# Round-table clips recorded without captions (NOCAPTION=1 record-all.sh)
for lang in zh en; do
  cp $MEDIA/roundtable-$lang-clean.mp4 $DIST/media/roundtable-$lang.mp4
  ffmpeg -loglevel error -y -sseof -1 -i $MEDIA/roundtable-$lang-clean.mp4 -frames:v 1 -q:v 3 $DIST/media/roundtable-$lang.jpg
done
cp $ROOT/casebase/Assets.xcassets/AppIcon.appiconset/casebase@2x-3.png $DIST/assets/icon-64.png
cp $ROOT/casebase/Assets.xcassets/AppIcon.appiconset/casebase@2x-1.png $DIST/assets/icon-256.png
[[ -f $SITE/og.png ]] && cp $SITE/og.png $DIST/assets/og.png
cp $ROOT/build/release/Casebase-$VERSION-arm64.dmg $DIST/downloads/
# Star count as of this build, so the page can show it without asking GitHub (rate limits, slow networks).
STARS=$(gh api repos/Raozhu/casebase --jq .stargazers_count 2>/dev/null || echo "")
[[ -n $STARS ]] && echo "{\"stars\": $STARS}" > $DIST/stars.json
echo $DIST
