#!/bin/sh
# Xcode Cloud runs this after cloning the repo.
#
# The TMDB key is never in the repo. Xcode Cloud passes it in as the secret
# environment variable TMDB_API_KEY (set in the workflow's Environment
# settings), and this writes the gitignored Secrets.xcconfig the build reads.
set -eu

cd "$CI_PRIMARY_REPOSITORY_PATH/ios"

if [ -z "${TMDB_API_KEY:-}" ]; then
    echo "TMDB_API_KEY isn't set in the Xcode Cloud workflow; the build will have no search." >&2
    exit 0
fi

# xcconfig treats "//" as a comment, so a value containing it would be cut off.
case "$TMDB_API_KEY" in
    *//*) echo "TMDB_API_KEY contains '//', which xcconfig can't hold." >&2; exit 1 ;;
esac

umask 077
printf 'TMDB_API_KEY = %s\n' "$TMDB_API_KEY" > Secrets.xcconfig
echo "Wrote ios/Secrets.xcconfig from the TMDB_API_KEY secret."
