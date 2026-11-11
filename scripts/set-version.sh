#!/bin/bash
# Xcode «Run Script» (останній етап збірки) для застосунку і віджета.
#
# Версія = <VERSION>.<кількість комітів>, збірка = кількість комітів.
# Тобто кожен новий коміт (а отже й кожен пуш) дає нову версію й новий номер збірки.
# Старші два числа (major.minor) змінюються вручну у файлі VERSION.
#
# Застосунок і віджет обчислюють однакові значення з того самого коміту,
# тому їхні CFBundleVersion завжди збігаються (цього вимагає iOS).
set -euo pipefail

PLISTBUDDY="${PLISTBUDDY:-/usr/libexec/PlistBuddy}"
ROOT="${SRCROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
cd "$ROOT"

BASE="$(tr -d '[:space:]' < VERSION)"
if ! [[ "$BASE" =~ ^[0-9]+\.[0-9]+$ ]]; then
  echo "error: VERSION має мати вигляд MAJOR.MINOR (наприклад 1.0), а не '$BASE'" >&2
  exit 1
fi

# Без git (наприклад, архів без історії) лишаємо значення з налаштувань проєкту.
if COUNT="$(git rev-list --count HEAD 2>/dev/null)" && [ "$COUNT" -ge 1 ]; then
  :
else
  COUNT="${CURRENT_PROJECT_VERSION:-1}"
  echo "warning: git-історії немає, використовую номер збірки $COUNT" >&2
fi

SHORT="$BASE.$COUNT"

# Для перевірки логіки без Xcode: SET_VERSION_PRINT_ONLY=1
if [ "${SET_VERSION_PRINT_ONLY:-0}" = "1" ]; then
  echo "$SHORT $COUNT"
  exit 0
fi

PLIST="${TARGET_BUILD_DIR}/${INFOPLIST_PATH}"
[ -f "$PLIST" ] || { echo "error: не знайдено Info.plist: $PLIST" >&2; exit 1; }

"$PLISTBUDDY" -c "Set :CFBundleShortVersionString $SHORT" "$PLIST"
"$PLISTBUDDY" -c "Set :CFBundleVersion $COUNT" "$PLIST"
echo "Версія: $SHORT (збірка $COUNT)"
