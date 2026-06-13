#!/usr/bin/env bash
# Renders the Claude Code status line from the native stdin JSON.
# Bar: ⛭ <model> · <dir> · [<effort> · ] [ctx <bar> <pct>% · ] [5h <bar> <pct>% · ] [wk <bar> <pct>%]
#
# The 5h/wk percentages are Anthropic's real rate-limit figures — the same
# numbers /usage shows — read straight from `rate_limits.*.used_percentage`.
# They appear only for Pro/Max subscribers, and only after the first API
# response of a session; each window can be independently absent, in which
# case its segment is dropped. Effort is the live session value (mid-session
# /effort changes included; ultracode reports as xhigh).
#
# Colours use a blue→amber→red threshold axis (colour-blind-safe; the theme
# here is daltonized) and the percentage text always carries the real value,
# so colour is decorative, never the sole signal.
# Field reference: https://code.claude.com/docs/en/statusline.md

set -u
jq -r --arg home "$HOME" '
  def c($n): "\u001b[38;5;\($n)m";
  def bold:  "\u001b[1m";
  def dim:   "\u001b[2m";
  def rst:   "\u001b[0m";

  # blue (calm) → amber (watch) → red+bold (hot)
  def pctcol($p): if   $p >= 80 then bold + c(203)
                  elif $p >= 50 then c(214)
                  else              c(39)  end;
  # fixed-width fill bar with eighth-block sub-cell resolution (▏▎▍▌▋▊▉ → █)
  def bar($p; $n):
    ( [ ([$p, 0] | max), 100 ] | min ) as $q
    | (($q / 100) * $n) as $x
    | ($x | floor) as $full
    | ((($x - $full) * 8) | round) as $e
    | (if $e == 8 then $full + 1 else $full end) as $f2
    | (if $e == 8 then 0 else $e end) as $e2
    | ( [range(0; $n)]
        | map( if . < $f2 then "█"
               elif . == $f2 then (["░","▏","▎","▍","▌","▋","▊","▉"][$e2])
               else "░" end )
        | join("") );
  def usage($label; $p):
    dim + $label + " " + rst + pctcol($p) + bar($p; 8) + " \($p | round)%" + rst;

  # context fill: orange, bolding near the ~90% autocompact line
  def ctxcol($p): if $p >= 80 then bold + c(208) else c(208) end;
  def ctxseg($p):
    dim + "ctx " + rst + ctxcol($p) + bar($p; 8) + " \($p | round)%" + rst;

  def model: bold + c(45)  + (.model.display_name // .model.id // "claude") + rst;
  def dir: c(245) + (
      (.workspace.current_dir // .cwd // ".") as $d
      | if $d == $home then "~" else ($d | sub(".*/"; "")) end
    ) + rst;

  ( [ c(220) + "⛭" + rst + " " + model, dir ]
    + (if .effort.level then [ c(141) + .effort.level + rst ] else [] end)
    + (if .context_window.used_percentage != null
         then [ ctxseg(.context_window.used_percentage) ] else [] end)
    + (if .rate_limits.five_hour.used_percentage != null
         then [ usage("5h"; .rate_limits.five_hour.used_percentage) ] else [] end)
    + (if .rate_limits.seven_day.used_percentage != null
         then [ usage("wk"; .rate_limits.seven_day.used_percentage) ] else [] end)
  ) | join(dim + " · " + rst)
'
