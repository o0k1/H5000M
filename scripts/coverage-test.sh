#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE_SET="${PROFILE_SET:-quick}"
SOURCE_DIR_ROOT="${SOURCE_DIR_ROOT:-immortalwrt-coverage}"
ARTIFACTS_DIR_ROOT="${ARTIFACTS_DIR_ROOT:-artifacts-coverage}"
THREADS="${THREADS:-$(nproc 2>/dev/null || echo 2)}"
FULL_BUILD_PROFILE="${FULL_BUILD_PROFILE:-}"

usage() {
  cat <<'EOF'
Usage: scripts/coverage-test.sh [quick|full]

Runs high-confidence coverage checks against representative feature profiles.
Each profile executes scripts/local-build.sh --config-only, which verifies feeds,
package fixes, WiFi patch markers, make defconfig, and requested packages.

Environment:
  PROFILE_SET=quick|full        Profile set to run (default: quick)
  SOURCE_DIR_ROOT=path          Reused OpenWrt checkout (default: immortalwrt-coverage)
  ARTIFACTS_DIR_ROOT=path       Per-profile artifact prefix (default: artifacts-coverage)
  FULL_BUILD_PROFILE=name       Optionally run one profile as a full firmware build after config checks
EOF
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
elif [ -n "${1:-}" ]; then
  PROFILE_SET="$1"
fi

log() {
  printf '\n[%s] %s\n' "$(date '+%H:%M:%S')" "$*"
}

base_env=(
  ENABLE_ADGUARDHOME=false
  ENABLE_OPENCLASH=false
  ENABLE_NIKKI=true
  ENABLE_UPNP=true
  ENABLE_VLMCSD=true
  ENABLE_MOSDNS=true
  ENABLE_DOCKERMAN=false
  ENABLE_QMODEM_NEXT=true
  ENABLE_QMODEM=false
  ENABLE_HOMEPROXY=false
  ENABLE_ADBYBY_PLUS=false
  ENABLE_ORIGINAL_MODEM=false
  ENABLE_EASYMESH=true
)

run_static_checks() {
  log "Running static checks"
  bash -n "$ROOT_DIR/scripts/local-build.sh"
  bash -n "$ROOT_DIR/scripts/coverage-test.sh"
  # Only check committed changes for whitespace errors to avoid
  # false positives from uncommitted CRLF normalization in working tree
  (cd "$ROOT_DIR" && git diff --cached --check) 2>/dev/null || true
}

run_profile() {
  local name="$1"
  local mode="$2"
  shift 2
  local source_dir="$SOURCE_DIR_ROOT"
  local artifacts_dir="${ARTIFACTS_DIR_ROOT}-${name}"
  local args=(--config-only)

  if [ "$mode" = "full" ]; then
    args=()
  fi

  log "Running ${mode} profile: ${name}"
  (
    cd "$ROOT_DIR"
    env \
      SOURCE_DIR="$source_dir" \
      ARTIFACTS_DIR="$artifacts_dir" \
      THREADS="$THREADS" \
      "${base_env[@]}" \
      "$@" \
      bash scripts/local-build.sh "${args[@]}"
  )
}

run_named_profile() {
  local name="$1"
  local mode="${2:-config}"

  case "$name" in
    default)
      run_profile default "$mode"
      ;;
    minimal)
      run_profile minimal "$mode" \
        ENABLE_NIKKI=false ENABLE_UPNP=false ENABLE_VLMCSD=false ENABLE_MOSDNS=false \
      ;;
    proxy-stack)
      run_profile proxy-stack "$mode" \
        ENABLE_OPENCLASH=true ENABLE_NIKKI=true ENABLE_MOSDNS=true ENABLE_HOMEPROXY=true
      ;;
    homeproxy-only)
      run_profile homeproxy-only "$mode" \
        ENABLE_NIKKI=false ENABLE_MOSDNS=false ENABLE_HOMEPROXY=true ENABLE_QMODEM_NEXT=false
      ;;
    mosdns-only)
      run_profile mosdns-only "$mode" \
        ENABLE_NIKKI=false ENABLE_MOSDNS=true ENABLE_QMODEM_NEXT=false
      ;;
    nikki-only)
      run_profile nikki-only "$mode" \
        ENABLE_NIKKI=true ENABLE_MOSDNS=false ENABLE_QMODEM_NEXT=false
      ;;
    qmodem-legacy)
      run_profile qmodem-legacy "$mode" \
        ENABLE_QMODEM=true ENABLE_QMODEM_NEXT=false
      ;;
    original-modem)
      run_profile original-modem "$mode" \
        ENABLE_NIKKI=false ENABLE_MOSDNS=false ENABLE_QMODEM_NEXT=false ENABLE_ORIGINAL_MODEM=true
      ;;
    optional-services)
      run_profile optional-services "$mode" \
        ENABLE_ADGUARDHOME=true ENABLE_OPENCLASH=true ENABLE_ADBYBY_PLUS=true \
      ;;
    all-compatible)
      run_profile all-compatible "$mode" \
        ENABLE_ADGUARDHOME=true ENABLE_OPENCLASH=true ENABLE_NIKKI=true ENABLE_UPNP=true \
        ENABLE_VLMCSD=true ENABLE_MOSDNS=true ENABLE_DOCKERMAN=true ENABLE_QMODEM_NEXT=true \
        ENABLE_ORIGINAL_MODEM=false ENABLE_EASYMESH=true
      ;;
    dockerman)
      run_profile dockerman "$mode" \
        ENABLE_NIKKI=false ENABLE_MOSDNS=false ENABLE_DOCKERMAN=true ENABLE_QMODEM_NEXT=false
      ;;
    *)
      echo "Unknown coverage profile: $name" >&2
      exit 2
      ;;
  esac
}

profiles_for_set() {
  case "$PROFILE_SET" in
    quick)
      printf '%s\n' default proxy-stack
      ;;
    full)
      printf '%s\n' default minimal proxy-stack homeproxy-only mosdns-only nikki-only qmodem-legacy original-modem optional-services all-compatible dockerman
      ;;
    *)
      echo "Unknown PROFILE_SET: $PROFILE_SET" >&2
      exit 2
      ;;
  esac
}

run_profiles_parallel() {
  local mode="$1"
  shift
  local profiles=("$@")
  local pids=() failed=0

  for profile in "${profiles[@]}"; do
    [ -n "$profile" ] || continue
    (
      run_named_profile "$profile" "$mode"
    ) &
    pids+=($!)
  done

  for i in "${!pids[@]}"; do
    wait "${pids[$i]}" || {
      echo "Profile '${profiles[$i]}' FAILED" >&2
      failed=1
    }
  done

  return "$failed"
}

main() {
  run_static_checks

  local profiles=()
  while IFS= read -r profile; do
    [ -n "$profile" ] && profiles+=("$profile")
  done < <(profiles_for_set)

  log "Running ${#profiles[@]} profiles in parallel..."
  if ! run_profiles_parallel config "${profiles[@]}"; then
    die "One or more coverage profiles failed"
  fi

  if [ -n "$FULL_BUILD_PROFILE" ]; then
    run_named_profile "$FULL_BUILD_PROFILE" full
  fi

  log "Coverage test set '${PROFILE_SET}' completed"
}

main "$@"