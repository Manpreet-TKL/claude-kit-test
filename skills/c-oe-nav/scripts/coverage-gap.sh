#!/bin/bash -l
# Manpreet 24/07/2026
# Reports OpenEyes frontend documentation coverage: cross-references the
# vendored page index (subs/page-index.md - ground truth of every area/page)
# against c-oe-nav's current field-level docs (admin-forms.md, event-forms.md,
# app-forms.md). No agents, no host-local checkout - pure awk/grep. Re-run any
# time the page index or the atlas changes to see what drifted.

abort() {
    echo >&2 '
****************************
*** ABORTED DUE TO ERROR ***
****************************
'
    date
    echo "An error occurred. Exiting..." >&2
    exit 1
}

trap 'abort' 0
set -e

##################################################
### VARIABLES (See end of script for execution) ##
##################################################

skill_root="$(dirname "$(dirname "$(realpath "$0")")")"
page_index="${skill_root}/subs/page-index.md"
admin_forms="${skill_root}/subs/admin-forms.md"
event_forms="${skill_root}/subs/event-forms.md"
app_forms="${skill_root}/subs/app-forms.md"

##################################################
### CHECKS (See end of script for execution)    ##
##################################################

echo -e "\nStarting Pre-flight checks ..."
echo "-------------------------------"

echo "Checking page index exists..."
[ -f "${page_index}" ] || { echo "Page index not found at ${page_index} (regenerate with build-page-index.sh)"; exit 1; }
echo "[OK]"

echo "Checks complete ..."
echo "-------------------------------"

##################################################
### FUNCTIONS (See end of script for execution) ##
##################################################

# One "<area>\t<page count>" line per area, in the index's order.
areaCounts() {
    awk -F' \\| ' '/^\| / && $1 != "| Area" { sub(/^\| /, "", $1); print $1 }' "${page_index}" \
        | uniq -c \
        | awk '{ print $2 "\t" $1 }'
}

reportAdmin() {
    local expected_sections index_admin_pages doc_sections doc_total_pages tier

    expected_sections="$(areaCounts | grep -c '^admin/' || true)"
    index_admin_pages="$(areaCounts | awk -F'\t' '$1 ~ /^admin\// { s += $2 } END { print s+0 }')"

    if [ ! -f "${admin_forms}" ]; then
        printf '%-24s %-8s %-14s %s\n' "admin" "${index_admin_pages}" "UNDOCUMENTED" "admin-forms.md missing"
        return
    fi

    doc_sections="$(grep -c '^### ' "${admin_forms}" || true)"
    doc_total_pages="$(
        { grep -oE '\([0-9]+ pages total' "${admin_forms}" || true
          grep -oE 'All [0-9]+ pages are the plain lookup-table' "${admin_forms}" || true
        } | grep -oE '[0-9]+' | awk '{s+=$1} END{print s+0}'
    )"

    tier="field-level"
    [ "${doc_sections}" != "${expected_sections}" ] && tier="CHECK"
    [ "${doc_total_pages}" != "${index_admin_pages}" ] && tier="CHECK"

    printf '%-24s %-8s %-14s %s\n' "admin" "${index_admin_pages}" "${tier}" \
        "${doc_sections}/${expected_sections} sections, ${doc_total_pages}/${index_admin_pages} pages accounted for (admin-forms.md)"
}

reportNonAdmin() {
    local area count tier detail n

    while IFS=$'\t' read -r area count; do
        case "${area}" in
        menu-bar | patient-summary | worklist)
            tier="atlas-only"
            detail="by design - paths.md"
            ;;
        add-event)
            if [ -f "${event_forms}" ]; then
                n="$(grep -c '^### ' "${event_forms}" || true)"
                tier="field-level"
                detail="${n} event types documented (event-forms.md)"
            else
                tier="UNDOCUMENTED"
                detail="event-forms.md missing"
            fi
            ;;
        *)
            if [ -f "${app_forms}" ] && grep -qi "${area}" "${app_forms}"; then
                tier="field-level"
                detail="app-forms.md"
            else
                tier="UNDOCUMENTED"
                detail="no field-level doc found"
                undocumented_areas+=("${area} (${count} pages)")
            fi
            ;;
        esac
        printf '%-24s %-8s %-14s %s\n' "${area}" "${count}" "${tier}" "${detail}"
    done < <(areaCounts | grep -v '^admin/')
}

##################################################
################# EXECUTION ######################
##################################################

undocumented_areas=()

echo -e "\nOpenEyes frontend coverage gap report"
echo "======================================"
echo "Page index: $(sed -n '4p' "${page_index}" | sed 's/ \*\*Grep.*//')"
echo ""
printf '%-24s %-8s %-14s %s\n' "AREA" "PAGES" "TIER" "DETAIL"
printf '%-24s %-8s %-14s %s\n' "----" "-----" "----" "------"

reportAdmin
reportNonAdmin

echo ""
if [ "${#undocumented_areas[@]}" -eq 0 ]; then
    echo "No genuinely undocumented areas found."
else
    echo "Undocumented (${#undocumented_areas[@]}):"
    for a in "${undocumented_areas[@]}"; do
        echo "  - ${a}"
    done
fi
echo -e "[Done]\n"

trap : 0
echo >&2 ""
echo "**************************************************"
echo "**************************************************"
echo "***************COVERAGE GAP REPORT DONE**********"
echo "**************************************************"
echo "**************************************************"
