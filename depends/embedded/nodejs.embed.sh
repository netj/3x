#!/usr/bin/env bash
# extract essential nodejs files
# Usage: .../nodejs.embed.sh  PREPARED_NODEJS_DIR  STAGING_DIR
set -eu

[ $# -eq 2 ]
from=$1 to=$2

# copy only the installed files
rsync -aH "$from"/prefix/ "$to"/nodejs/

# expose commands under bin/ using symlinks
cd "$to"
mkdir -p bin
for x in nodejs/bin/*; do
    ln -sfn ../"$x" bin/
done
