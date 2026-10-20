#!/usr/bin/env bash
# Print the greatest tag by SemVer precedence.
# Tags must be vMAJOR.MINOR.PATCH or vMAJOR.MINOR.PATCH-prerelease.
# Git's version sort ranks v1.2.3-rc.1 above v1.2.3; a final release outranks its prerelease.
set -euo pipefail
export LC_ALL=C

version_re='^v[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.-]+)?$'

strip0() {
  local n=$1
  n=${n#"${n%%[!0]*}"}
  printf '%s' "${n:-0}"
}

# Print 1, 0, or -1 for unsigned integer strings $1 ? $2.
cmp_num() {
  local a b
  a=$(strip0 "$1")
  b=$(strip0 "$2")
  if [ "$a" = "$b" ]; then
    printf '0'
  elif [ "${#a}" -gt "${#b}" ] || { [ "${#a}" -eq "${#b}" ] && [ "$a" \> "$b" ]; }; then
    printf '1'
  else
    printf '%s' '-1'
  fi
}

# Return 0 when $1 is strictly greater than $2.
version_gt() {
  local a=${1#v} b=${2#v}
  local a_core a_pre b_core b_pre
  local aM am ap bM bm bp
  local c i n m limit ai bi a_num b_num rest
  local -a A=() B=()

  if [[ "$a" == *-* ]]; then
    a_core=${a%%-*}
    a_pre=${a#*-}
  else
    a_core=$a
    a_pre=
  fi
  if [[ "$b" == *-* ]]; then
    b_core=${b%%-*}
    b_pre=${b#*-}
  else
    b_core=$b
    b_pre=
  fi

  IFS=. read -r aM am ap <<< "$a_core"
  IFS=. read -r bM bm bp <<< "$b_core"

  c=$(cmp_num "$aM" "$bM")
  [ "$c" = 1 ] && return 0
  [ "$c" = -1 ] && return 1
  c=$(cmp_num "$am" "$bm")
  [ "$c" = 1 ] && return 0
  [ "$c" = -1 ] && return 1
  c=$(cmp_num "$ap" "$bp")
  [ "$c" = 1 ] && return 0
  [ "$c" = -1 ] && return 1

  if [ -z "$a_pre" ] && [ -z "$b_pre" ]; then
    return 1
  fi
  if [ -z "$a_pre" ]; then
    return 0
  fi
  if [ -z "$b_pre" ]; then
    return 1
  fi

  rest=$a_pre
  while [[ "$rest" == *.* ]]; do
    A+=("${rest%%.*}")
    rest=${rest#*.}
  done
  A+=("$rest")
  rest=$b_pre
  while [[ "$rest" == *.* ]]; do
    B+=("${rest%%.*}")
    rest=${rest#*.}
  done
  B+=("$rest")

  n=${#A[@]}
  m=${#B[@]}
  if [ "$n" -lt "$m" ]; then
    limit=$n
  else
    limit=$m
  fi
  i=0
  while [ "$i" -lt "$limit" ]; do
    ai=${A[$i]}
    bi=${B[$i]}
    if [ "$ai" = "$bi" ]; then
      i=$((i + 1))
      continue
    fi
    a_num=0
    b_num=0
    [[ "$ai" =~ ^[0-9]+$ ]] && a_num=1
    [[ "$bi" =~ ^[0-9]+$ ]] && b_num=1
    if [ "$a_num" -eq 1 ] && [ "$b_num" -eq 1 ]; then
      c=$(cmp_num "$ai" "$bi")
      [ "$c" = 1 ] && return 0
      [ "$c" = -1 ] && return 1
      i=$((i + 1))
      continue
    fi
    if [ "$a_num" -eq 1 ]; then
      return 1
    fi
    if [ "$b_num" -eq 1 ]; then
      return 0
    fi
    [ "$ai" \> "$bi" ] && return 0
    return 1
  done
  [ "$n" -gt "$m" ]
}

tags=$(git tag --list 'v*')
best=
while IFS= read -r tag; do
  [ -n "$tag" ] || continue
  [[ "$tag" =~ $version_re ]] || continue
  if [ -z "$best" ] || version_gt "$tag" "$best"; then
    best=$tag
  fi
done <<END_TAGS
$tags
END_TAGS

if [ -z "$best" ]; then
  echo "no SemVer tags matching vX.Y.Z or vX.Y.Z-prerelease" >&2
  exit 1
fi
printf '%s\n' "$best"
