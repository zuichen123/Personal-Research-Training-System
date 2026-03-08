#!/usr/bin/env sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
CLIENT_DIR="$ROOT_DIR/apps/flutter_client"
DIST_DIR="$ROOT_DIR/dist/flutter-client"

if [ ! -d "$CLIENT_DIR" ]; then
  echo "Flutter client directory not found: $CLIENT_DIR" >&2
  exit 1
fi

FLUTTER_BIN="flutter"
API_BASE_URL=""
SKIP_PUB_GET=0
DRY_RUN=0
TARGETS_CSV=""

print_usage() {
  cat <<'EOF'
Usage: scripts/build-client.sh [options]

Options:
  --target <windows|web|apk|all>   Add a build target. Can be repeated.
  --flutter-bin <path>             Flutter executable to use. Default: flutter
  --api-base-url <url>             Optional API_BASE_URL dart-define.
  --skip-pub-get                   Skip flutter pub get.
  --dry-run                        Print commands without executing them.
  -h, --help                       Show this help.
EOF
}

append_target() {
  target="$1"
  case ",$TARGETS_CSV," in
    *,"$target",*)
      ;;
    *)
      if [ -n "$TARGETS_CSV" ]; then
        TARGETS_CSV="$TARGETS_CSV,$target"
      else
        TARGETS_CSV="$target"
      fi
      ;;
  esac
}

normalize_target() {
  case "$1" in
    all)
      append_target windows
      append_target web
      append_target apk
      ;;
    windows|web|apk)
      append_target "$1"
      ;;
    *)
      echo "Unsupported target: $1" >&2
      exit 1
      ;;
  esac
}

while [ $# -gt 0 ]; do
  case "$1" in
    --target)
      if [ $# -lt 2 ]; then
        echo "Missing value for --target" >&2
        exit 1
      fi
      normalize_target "$2"
      shift 2
      ;;
    --flutter-bin)
      if [ $# -lt 2 ]; then
        echo "Missing value for --flutter-bin" >&2
        exit 1
      fi
      FLUTTER_BIN="$2"
      shift 2
      ;;
    --api-base-url)
      if [ $# -lt 2 ]; then
        echo "Missing value for --api-base-url" >&2
        exit 1
      fi
      API_BASE_URL="$2"
      shift 2
      ;;
    --skip-pub-get)
      SKIP_PUB_GET=1
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      print_usage
      exit 0
      ;;
    *)
      echo "Unsupported argument: $1" >&2
      print_usage >&2
      exit 1
      ;;
  esac
done

if [ -z "$TARGETS_CSV" ]; then
  TARGETS_CSV="windows"
fi

mkdir -p "$DIST_DIR"

run_flutter() {
  description="$1"
  shift

  display_args="$*"
  if [ -n "$API_BASE_URL" ]; then
    display_args="$display_args --dart-define=API_BASE_URL=$API_BASE_URL"
  fi

  echo ">> $description"
  echo "   $FLUTTER_BIN $display_args"

  if [ "$DRY_RUN" -eq 1 ]; then
    return 0
  fi

  if [ -n "$API_BASE_URL" ]; then
    "$FLUTTER_BIN" "$@" "--dart-define=API_BASE_URL=$API_BASE_URL"
  else
    "$FLUTTER_BIN" "$@"
  fi
}

reset_destination() {
  path="$1"
  rm -rf "$path"
  mkdir -p "$path"
}

publish_directory() {
  source_dir="$1"
  destination_dir="$2"

  if [ "$DRY_RUN" -eq 1 ]; then
    echo "   [dry-run] copy $source_dir -> $destination_dir"
    return 0
  fi

  if [ ! -d "$source_dir" ]; then
    echo "Build output not found: $source_dir" >&2
    exit 1
  fi

  reset_destination "$destination_dir"
  cp -R "$source_dir/." "$destination_dir/"
}

publish_file() {
  source_file="$1"
  destination_file="$2"

  if [ "$DRY_RUN" -eq 1 ]; then
    echo "   [dry-run] copy $source_file -> $destination_file"
    return 0
  fi

  if [ ! -f "$source_file" ]; then
    echo "Build output not found: $source_file" >&2
    exit 1
  fi

  mkdir -p "$(dirname -- "$destination_file")"
  cp "$source_file" "$destination_file"
}

ORIGINAL_DIR=$(pwd)
trap 'cd "$ORIGINAL_DIR"' EXIT INT TERM
cd "$CLIENT_DIR"

if [ "$SKIP_PUB_GET" -eq 0 ]; then
  run_flutter "flutter pub get" pub get
fi

OLD_IFS=$IFS
IFS=,
set -- $TARGETS_CSV
IFS=$OLD_IFS

for target in "$@"; do
  case "$target" in
    windows)
      run_flutter "build Flutter Windows client" build windows
      publish_directory "$CLIENT_DIR/build/windows/x64/runner/Release" "$DIST_DIR/windows"
      ;;
    web)
      run_flutter "build Flutter Web client" build web
      publish_directory "$CLIENT_DIR/build/web" "$DIST_DIR/web"
      ;;
    apk)
      run_flutter "build Flutter Android APK" build apk
      publish_file "$CLIENT_DIR/build/app/outputs/flutter-apk/app-release.apk" "$DIST_DIR/apk/app-release.apk"
      ;;
  esac
done

echo "Done. Artifacts staged in $DIST_DIR"
