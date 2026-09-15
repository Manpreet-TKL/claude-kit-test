#!/bin/bash -l
# Manpreet 14/09/2026
# Set kit profile defaults without overriding native session model selection.

setCodexProfileDefaults() (
    local profile="${1}" model="${2}" effort="${3}" verbosity="${4:-}" temporary=""
    [[ "${model}" =~ ^[a-zA-Z0-9._-]+$ ]] || return 1
    [[ "${effort}" =~ ^[a-zA-Z0-9._-]+$ ]] || return 1
    case "${verbosity}" in ''|low|medium|high) ;; *) return 1 ;; esac
    [ -f "${profile}" ] || return 1
    # Lock a separate inode because replacing the profile releases inode locks.
    exec 9>"${profile}.lock"
    flock -x 9 || return 1
    trap '[ -z "${temporary}" ] || rm -f "${temporary}"' EXIT
    temporary="$(mktemp "${profile}.tmp.XXXXXX")" || return 1
    awk -v model="${model}" -v effort="${effort}" -v verbosity="${verbosity}" '
        function defaults() {
            if (!wrote_model) print "model = \"" model "\""
            if (!wrote_effort) print "model_reasoning_effort = \"" effort "\""
            if (verbosity != "" && !wrote_verbosity) print "model_verbosity = \"" verbosity "\""
        }
        /^[[:space:]]*\[/ && !section { defaults(); section = 1 }
        !section && /^[[:space:]]*model[[:space:]]*=/ {
            print "model = \"" model "\""; wrote_model = 1; next
        }
        !section && /^[[:space:]]*model_reasoning_effort[[:space:]]*=/ {
            print "model_reasoning_effort = \"" effort "\""; wrote_effort = 1; next
        }
        !section && verbosity != "" && /^[[:space:]]*model_verbosity[[:space:]]*=/ {
            print "model_verbosity = \"" verbosity "\""; wrote_verbosity = 1; next
        }
        { print }
        END { if (!section) defaults() }
    ' "${profile}" > "${temporary}" || return 1
    chmod --reference="${profile}" "${temporary}" || return 1
    if ! cmp -s "${profile}" "${temporary}"; then
        mv "${temporary}" "${profile}" || return 1
    fi
)

codexStartsFreshSession() {
    while [ $# -gt 0 ]; do
        case "${1}" in
            --) return 0 ;;
            -c|--config|-C|--cd|-m|--model|-p|--profile|-i|--image|--add-dir|--enable|--disable|-s|--sandbox|-a|--ask-for-approval|--remote|--remote-env)
                [ $# -ge 2 ] || return 0
                shift
                ;;
            -*) ;;
            exec|e) ;;
            resume|fork) return 1 ;;
            *) return 0 ;;
        esac
        shift
    done
    return 0
}
