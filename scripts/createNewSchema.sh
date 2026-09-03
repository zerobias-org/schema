#!/bin/sh
# Scaffold a new schema package from templates/.
#
# Usage: scripts/createNewSchema.sh package/<vendor>/<code>
#        scripts/createNewSchema.sh package/<vendor>/<group>/<code>
#
# The path is repo-root-relative and must include the package/ prefix.
# The directory must already exist (mkdir -p it first).
set -e

if [ $# -ne 1 ]; then
    echo "Usage: $0 package/<vendor>/[<group>/]<code>"
    exit 1
fi

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
FOLDER_PATH=${1%/}

case "$FOLDER_PATH" in
  package/*) ;;
  *) echo "Path must be repo-root-relative and start with package/ — got: $FOLDER_PATH"; exit 1 ;;
esac

TARGET="$REPO_ROOT/$FOLDER_PATH"
if [ ! -d "$TARGET" ]; then
  echo "Folder $FOLDER_PATH does not exist. Create it first: mkdir -p $FOLDER_PATH"
  exit 1
fi

REL=${FOLDER_PATH#package/}
# Umbrella schemas (…/schema) drop the trailing segment when deriving names
NAME_REL=$REL
case "$NAME_REL" in
  */schema) NAME_REL=${NAME_REL%/schema} ;;
esac
DASHED=$(printf '%s' "$NAME_REL" | tr '/' '-')
DOTTED=$(printf '%s' "$NAME_REL" | tr '/' '.')

cp "$REPO_ROOT/templates/catalog.yml" "$TARGET/"
cp "$REPO_ROOT/templates/package.json" "$TARGET/"
cp "$REPO_ROOT/.npmrc" "$TARGET/"

# In-place sed portable across BSD (macOS) and GNU sed
subst() {
  sed -i.bak -e "s|{dashed}|$DASHED|g" -e "s|{dotted}|$DOTTED|g" -e "s|{path}|$REL|g" "$1"
  rm -f "$1.bak"
}
subst "$TARGET/package.json"
subst "$TARGET/catalog.yml"

# Gradle discovery marker — settings.gradle.kts finds packages by this file
if [ ! -f "$TARGET/build.gradle.kts" ]; then
  printf 'plugins { id("zb.schema") }\n' > "$TARGET/build.gradle.kts"
fi

echo "Scaffolded $FOLDER_PATH"
echo "  npm name:         @zerobias-org/schema-$DASHED"
echo "  zerobias.package: $DOTTED.schema"
echo "Next:"
echo "  1. Fill {name} / {description} in catalog.yml and package.json"
echo "  2. Author definitions under classes/ interfaces/ fields/ enums/ documents/"
echo "  3. cd $FOLDER_PATH && zbb gate   (commit gate-stamp.json)"
