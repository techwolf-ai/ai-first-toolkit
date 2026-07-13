# Sourceable dispatcher: specto_dispatch <domain> <verb> [args…]
#
# Resolves the configured backend for <domain> (forge|tracker|vcs) via
# lib/config.sh and execs scripts/<domain>/<backend>/<verb>.sh with the
# caller's argv verbatim (including --from-fixture; fixtures are
# backend-shaped, the decision-line output is backend-neutral).
#
# Exit codes (on top of whatever the backend impl returns):
#   3  no backend configured/detectable (guidance on stderr)
#   4  the verb has no implementation on the selected backend
#
# Test override: SPECTO_BACKEND_OVERRIDE_FORGE / _TRACKER / _VCS pin a backend
# without touching config files (contract tests use this).

SPECTO_DISPATCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SPECTO_DISPATCH_DIR/config.sh"

specto_dispatch() {
  local domain="$1" verb="$2"
  shift 2
  local backend=""
  case "$domain" in
    forge)   backend="${SPECTO_BACKEND_OVERRIDE_FORGE:-}"
             [[ -z "$backend" ]] && backend="$(specto_forge_backend)"   || true ;;
    tracker) backend="${SPECTO_BACKEND_OVERRIDE_TRACKER:-}"
             [[ -z "$backend" ]] && backend="$(specto_tracker_backend)" || true ;;
    vcs)     backend="${SPECTO_BACKEND_OVERRIDE_VCS:-}"
             [[ -z "$backend" ]] && backend="$(specto_vcs_backend)"     || true ;;
    *) echo "specto_dispatch: unknown domain '$domain'" >&2; exit 2 ;;
  esac
  [[ -z "$backend" ]] && exit 3
  case "$backend" in
    */*|.*) echo "specto_dispatch: invalid backend name '$backend'" >&2; exit 2 ;;
  esac
  local impl="$SPECTO_DISPATCH_DIR/../$domain/$backend/$verb.sh"
  if [[ ! -f "$impl" ]]; then
    echo "specto: '$verb' is not supported on backend '$backend'" >&2
    exit 4
  fi
  exec bash "$impl" "$@"
}
