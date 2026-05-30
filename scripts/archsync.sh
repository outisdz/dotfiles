#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# arch-update — Arch Linux System Update Orchestrator
# Handles: pacman · yay (AUR) · Python venv · cleanup
#
# Usage:  arch-update [OPTIONS]
#
# Options:
#   --noconfirm    Pass --noconfirm to pacman/yay
#   --no-aur       Skip AUR (yay) phase
#   --no-python    Skip Python venv phase
#   --cleanup      Enable orphan/cache cleanup phase
#   --no-notify    Suppress desktop notification
#   -h, --help     Show this help
#
# Author: Subaru
# ─────────────────────────────────────────────────────────────

set -euo pipefail
IFS=$'\n\t'

# ──────────────── Configuration (override via env) ─────────────
VENV_PATH="${ARCH_UPDATE_VENV:-${HOME}/pvenv}"
LOG_DIR="${XDG_STATE_HOME:-${HOME}/.local/state}/arch-update"
LOG_FILE="${LOG_DIR}/update.log"
LOCK_FILE="/tmp/arch-update.lock"
NOTIFY_ICON="$(logo_fastfetch 2>/dev/null || true)"

# ──────────────── Argument Parsing ─────────────────────────────
NOCONFIRM=false
SKIP_AUR=false
SKIP_PYTHON=false
SKIP_CLEANUP=true
SKIP_NOTIFY=false

_usage() {
    grep '^#' "$0" | grep -E '^\# ( Usage:|  --|  -h)' | sed 's/^# //'
    exit 0
}

for arg in "$@"; do
    case "$arg" in
        --noconfirm)  NOCONFIRM=true ;;
        --no-aur)     SKIP_AUR=true ;;
        --no-python)  SKIP_PYTHON=true ;;
        --cleanup)    SKIP_CLEANUP=false ;;
        --no-notify)  SKIP_NOTIFY=true ;;
        -h|--help)    _usage ;;
        *) printf "Unknown option: %s\n(use --help for usage)\n" "$arg" >&2; exit 1 ;;
    esac
done

# ──────────────── Colors ───────────────────────────────────────
if [[ -t 1 ]] && command -v tput >/dev/null 2>&1; then
    RED=$(tput setaf 1);     GREEN=$(tput setaf 2);   YELLOW=$(tput setaf 3)
    BLUE=$(tput setaf 4);    MAGENTA=$(tput setaf 5); CYAN=$(tput setaf 6)
    WHITE=$(tput setaf 7);   BOLD=$(tput bold);       DIM=$(tput dim)
    RESET=$(tput sgr0)
else
    RED=''; GREEN=''; YELLOW=''; BLUE=''; MAGENTA=''; CYAN=''
    WHITE=''; BOLD=''; DIM=''; RESET=''
fi

# ──────────────── Logging ──────────────────────────────────────
mkdir -p "$LOG_DIR"
LOG_FILE="${LOG_DIR}/update-$(date +"%Y%m%d_%H%M%S").log"
# Clean up logs older than 30 days
find "$LOG_DIR" -name "update-*.log" -mtime +10 -delete
exec > >(tee -a "$LOG_FILE") 2>&1

_ts()   { printf "${DIM}%s${RESET}" "$(date +"%T")"; }
log()   { printf "%b\n"  "${CYAN}[*]${RESET} $(_ts)  ${WHITE}$1${RESET}"; }
ok()    { printf "%b\n"  "${GREEN}[✓]${RESET} $(_ts)  ${GREEN}$1${RESET}"; }
warn()  { printf "%b\n"  "${YELLOW}[!]${RESET} $(_ts)  ${YELLOW}$1${RESET}" >&2; }
fatal() { printf "%b\n"  "${BOLD}${RED}[✗]${RESET} $(_ts)  ${RED}$1${RESET}" >&2; _cleanup_lock; exit 1; }
skip()  { printf "%b\n"  "${DIM}[-]${RESET} $(_ts)  ${DIM}$1${RESET}"; }
step()  {
    printf "\n${BOLD}${MAGENTA}  ▶  %s${RESET}  ${DIM}%s${RESET}\n" "$1" \
        "────────────────────────────────────"
}

# ──────────────── Lock File ────────────────────────────────────
_cleanup_lock() { rm -f "$LOCK_FILE"; }

if [[ -e "$LOCK_FILE" ]]; then
    fatal "Another instance is running (lock: ${LOCK_FILE}). Exiting."
fi
touch "$LOCK_FILE"
trap '_cleanup_lock' EXIT INT TERM

# ──────────────── Privilege Check ─────────────────────────────
[[ "$EUID" -eq 0 ]] && fatal "Do not run as root. sudo will be invoked as needed."

sudo -v || fatal "sudo authentication failed"
( while true; do sudo -v; sleep 55; done ) &
_SUDO_KEEPALIVE_PID=$!
trap '_cleanup_lock; kill "$_SUDO_KEEPALIVE_PID" 2>/dev/null' EXIT INT TERM

# ──────────────── Notification Helper ─────────────────────────
_resolve_icon() {
    [[ -n "$NOTIFY_ICON" && -f "$NOTIFY_ICON" ]] && return
    local candidates=(
        "/usr/share/pixmaps/archlinux-logo.png"
        "/usr/share/icons/hicolor/128x128/apps/archlinux.png"
    )
    for c in "${candidates[@]}"; do
        [[ -f "$c" ]] && NOTIFY_ICON="$c" && return
    done
    NOTIFY_ICON=""
}

_notify() {
    "$SKIP_NOTIFY" && return
    command -v notify-send >/dev/null 2>&1 || return
    local icon_arg=()
    [[ -n "$NOTIFY_ICON" ]] && icon_arg=(-i "$NOTIFY_ICON")
    notify-send "${icon_arg[@]}" "$1" "$2" -t 6000 || true
}

# ──────────────── Banner ───────────────────────────────────────
_banner() {
    printf "\n${BOLD}${BLUE}Arch Update Session${RESET}"
    printf " ${DIM}—${RESET} "
    printf "${CYAN}%s${RESET}\n" "$(date +"%Y-%m-%d  %I:%M %p")"
    printf "${DIM}Log → %s${RESET}\n" "$LOG_FILE"
}

# ──────────────── Counters ─────────────────────────────────────
PHASES_OK=0
PHASES_WARN=0

_phase_ok()   { (( PHASES_OK++ ))   || true; ok "$1"; }
_phase_warn() { (( PHASES_WARN++ )) || true; warn "$1"; }

# ══════════════════════════════════════════════════════════════
#                          MAIN
# ══════════════════════════════════════════════════════════════
_resolve_icon
_banner

# ── 1. pacman ─────────────────────────────────────────────────
step "pacman — official repos"
log "Running pacman -Syu …"

pacman_flags=(-Syu)
"$NOCONFIRM" && pacman_flags+=(--noconfirm)

if sudo pacman "${pacman_flags[@]}"; then
    _phase_ok "pacman: system packages up to date"
else
    _phase_warn "pacman finished with non-zero status — review output above"
fi

# ── 2. yay (AUR) ──────────────────────────────────────────────
if ! "$SKIP_AUR"; then
    step "yay — AUR"
    if command -v yay >/dev/null 2>&1; then
        log "Running yay -Syu …"
        yay_flags=(-Syu --needed)
        "$NOCONFIRM" && yay_flags+=(--noconfirm)

        if yay "${yay_flags[@]}"; then
            _phase_ok "yay: AUR packages up to date"
        else
            _phase_warn "yay finished with non-zero status — review AUR output above"
        fi
    else
        warn "yay not found — skipping AUR phase (install from AUR: yay-bin)"
    fi
else
    skip "AUR phase skipped (--no-aur)"
fi

# ── 3. Cleanup — orphans & cache ──────────────────────────────
if ! "$SKIP_CLEANUP"; then
    step "Cleanup — orphans & cache"

    orphans=$(pacman -Qdtq 2>/dev/null || true)
    if [[ -n "$orphans" ]]; then
        log "Removing orphaned packages…"
        echo "$orphans" | sudo pacman -Rns - --noconfirm \
            && ok "Orphans removed" \
            || warn "Could not remove some orphans"
    else
        ok "No orphaned packages found"
    fi

    if command -v paccache >/dev/null 2>&1; then
        log "Pruning pacman cache (keeping 2 versions) …"
        sudo paccache -rk2 \
            && ok "Package cache pruned" \
            || warn "paccache returned non-zero"
    else
        warn "paccache not found (pacman-contrib) — skipping cache prune"
    fi
else
    skip "Cleanup skipped (pass --cleanup to enable)"
fi

# ── 4. Python venv ────────────────────────────────────────────
if ! "$SKIP_PYTHON"; then
    step "Python venv — ${VENV_PATH}"

    if [[ -d "$VENV_PATH" && -f "$VENV_PATH/bin/activate" ]]; then
        # shellcheck disable=SC1091
        source "$VENV_PATH/bin/activate" || fatal "Failed to activate venv at ${VENV_PATH}"

        if command -v pip-review >/dev/null 2>&1; then
            log "Running pip-review --auto …"
            if pip-review --auto; then
                _phase_ok "pip dependencies up to date"
            else
                _phase_warn "pip-review returned non-zero — some packages may need attention"
            fi
        else
            log "pip-review not found; falling back to pip list --outdated"
            outdated=$(pip list --outdated --format=columns 2>/dev/null || true)
            if [[ -n "$outdated" ]]; then
                warn "Outdated packages detected (install pip-review to auto-update):"
                printf "%b\n" "${YELLOW}${outdated}${RESET}"
            else
                ok "All pip packages appear current"
            fi
        fi

        deactivate || true
    else
        warn "No venv at ${VENV_PATH} — skipping (set ARCH_UPDATE_VENV to override)"
    fi
else
    skip "Python phase skipped (--no-python)"
fi

# ──────────────── Summary ──────────────────────────────────────
printf "\n${BOLD}${BLUE}Summary${RESET}  ${DIM}────────────────────────────────────${RESET}\n"
printf "  ${GREEN}✓${RESET}  Phases OK   ${BOLD}${GREEN}%s${RESET}\n" "$PHASES_OK"
if (( PHASES_WARN > 0 )); then
    printf "  ${YELLOW}!${RESET}  Warnings    ${BOLD}${YELLOW}%s${RESET}\n" "$PHASES_WARN"
fi
printf "  ${CYAN}◷${RESET}  Finished    ${CYAN}%s${RESET}\n\n" "$(date +"%I:%M:%S %p")"

if (( PHASES_WARN > 0 )); then
    _notify "Arch Update — done (with warnings)" \
        "$(date +"%T")  •  ${PHASES_WARN} phase(s) need attention"
else
    _notify "Arch Update — all clean ✓" \
        "$(date +"%T")  •  ${PHASES_OK} phase(s) completed"
fi

exit 0
