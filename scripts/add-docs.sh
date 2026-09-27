#!/usr/bin/env bash
# Adds the documentation to the built site (cucumberswift/CucumberSwift#152).
#
#   scripts/add-docs.sh _site
#
# Each package's releases carry their DocC docs as two assets, built for fixed
# paths: docs-major.zip for /<path>/X.x/ and docs-root.zip for /<path>/. For each
# package this script publishes:
#
#   /<path>/X.x/  the highest stable release of major X
#   /<path>/      the highest stable release overall
#
# Nothing is rebuilt. A zip that was built for another path is skipped, and the
# next lower release is used. Releases without the assets are skipped.
#
# It also writes redirect pages for the old documentation URLs, a fallback in
# 404.html, /docs/versions.json, sitemap.xml and robots.txt.
#
# Needs gh (with GH_TOKEN), jq, unzip and perl. A failed API call stops the
# script, so a site with docs missing is never deployed.
set -euo pipefail

out=${1:?usage: add-docs.sh <site directory>}
site_url=${SITE_URL:-https://cucumberswift.org}

# repository | path on the site | DocC module | old URL prefixes (space separated; "-" is the site root)
packages=(
  "${CUCUMBERSWIFT_REPO:-cucumberswift/CucumberSwift}|docs|cucumberswift|CucumberSwift -"
  "${EXPRESSIONS_REPO:-cucumberswift/CucumberSwiftExpressions}|docs/expressions|cucumberswiftexpressions|CucumberSwiftExpressions"
)

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
versions='[]'
sitemap="$work/sitemap.txt"
echo "$site_url/" > "$sitemap"
fallback=()

# The baseUrl DocC baked into a zip, e.g. /docs/5.x/.
base_url() {
  unzip -p "$1" index.html | sed -n 's/.*baseUrl = "\([^"]*\)".*/\1/p' | head -n 1
}

# Downloads <asset> of the first of <tags> (highest first) that was built for
# <base>, unpacks it into <dir> and prints its tag. Prints nothing if none fits.
publish_first() {
  local repo=$1 asset=$2 base=$3 dir=$4
  shift 4
  local tag zip
  for tag in "$@"; do
    zip="$work/$tag-$asset"
    gh release download "$tag" --repo "$repo" --pattern "$asset" --output "$zip" --clobber < /dev/null
    if [ "$(base_url "$zip")" = "$base" ]; then
      mkdir -p "$dir"
      unzip -q -o "$zip" -d "$dir"
      echo "$tag"
      return
    fi
    echo "::warning::$repo $tag: $asset is built for $(base_url "$zip"), not $base. Skipped." >&2
  done
}

redirect_page() {
  local file=$1 target=$2
  mkdir -p "$(dirname "$file")"
  cat > "$file" <<EOF
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Moved</title>
<link rel="canonical" href="$site_url$target">
<meta http-equiv="refresh" content="0; url=$target">
</head>
<body>
<p>This page has moved to <a href="$target">$site_url$target</a>.</p>
<script>location.replace("$target" + location.search + location.hash)</script>
</body>
</html>
EOF
}

# Pages of a DocC site, as paths relative to it, e.g. documentation/cucumberswift/hooks/.
pages() {
  local dirs=() d
  for d in documentation tutorials; do
    if [ -d "$1/$d" ]; then dirs+=("$d"); fi
  done
  if [ ${#dirs[@]} -gt 0 ]; then
    (cd "$1" && find "${dirs[@]}" -name index.html | sed 's|index.html$||' | sort)
  fi
}

for package in "${packages[@]}"; do
  IFS='|' read -r repo path module prefixes <<< "$package"
  echo "== $repo → /$path/"

  # Stable releases that carry both assets, lowest version first. Fetched on
  # its own, so a failed API call stops the script.
  releases=$(gh api --paginate "repos/$repo/releases?per_page=100" \
    --jq '.[] | select((.draft or .prerelease) | not)
              | select([.assets[].name] | index("docs-major.zip") and index("docs-root.zip"))
              | .tag_name')
  tags=$(grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' <<< "$releases" | sort -V || true)
  if [ -z "$tags" ]; then
    echo "::warning::$repo has no release with docs yet. /$path/ is not published."
    continue
  fi

  # /<path>/: the highest stable release overall.
  # shellcheck disable=SC2046 # one tag per word
  root=$(publish_first "$repo" docs-root.zip "/$path/" "$out/$path" $(sort -rV <<< "$tags"))
  if [ -z "$root" ]; then
    echo "::warning::$repo has no docs built for /$path/. /$path/ is not published."
    continue
  fi
  echo "/$path/: $root"
  redirect_page "$out/$path/index.html" "/$path/documentation/$module/"
  pages "$out/$path" | sed "s|^|$site_url/$path/|" >> "$sitemap"

  # /<path>/X.x/: the highest stable release of each major.
  latest_major="${root%%.*}.x"
  majors='[]'
  while read -r major; do
    # shellcheck disable=SC2046
    tag=$(publish_first "$repo" docs-major.zip "/$path/$major.x/" "$out/$path/$major.x" \
      $(grep "^$major\." <<< "$tags" | sort -rV))
    if [ -z "$tag" ]; then continue; fi
    echo "/$path/$major.x/: $tag"
    redirect_page "$out/$path/$major.x/index.html" "/$path/$major.x/documentation/$module/"
    majors=$(jq -c --arg m "$major.x" --arg v "$tag" --arg p "/$path/$major.x/" '. + [{major: $m, version: $v, path: $p}]' <<< "$majors")

    if [ "$major.x" = "$latest_major" ]; then
      # Same release as /<path>/: point search engines to /<path>/.
      pages "$out/$path/$major.x" | while read -r page; do
        CANONICAL="$site_url/$path/$page" perl -0pi -e 's|<head>|<head><link rel="canonical" href="$ENV{CANONICAL}">|' \
          "$out/$path/$major.x/${page}index.html"
      done
    else
      pages "$out/$path/$major.x" | sed "s|^|$site_url/$path/$major.x/|" >> "$sitemap"
    fi
  done < <(cut -d. -f1 <<< "$tags" | sort -un)

  # Old URLs, e.g. /CucumberSwift/documentation/cucumberswift/ → /docs/documentation/cucumberswift/.
  for prefix in $prefixes; do
    if [ "$prefix" = "-" ]; then legacy=""; else legacy="/$prefix"; fi
    pages "$out/$path" | while read -r page; do
      redirect_page "$out$legacy/${page}index.html" "/$path/$page"
    done
    if [ -n "$legacy" ]; then
      redirect_page "$out$legacy/index.html" "/$path/documentation/$module/"
      fallback+=("[\"$legacy/\", \"/$path/documentation/$module/\"]")
    else
      fallback+=("[\"/documentation/\", \"/$path/documentation/$module/\"]" "[\"/tutorials/\", \"/$path/documentation/$module/\"]")
    fi
  done

  versions=$(jq -c --arg n "${repo#*/}" --arg v "$root" --arg p "/$path/" --argjson m "$majors" \
    '. + [{name: $n, version: $v, path: $p, majors: $m}]' <<< "$versions")
done

# Old pages that no longer exist go to their package's documentation.
if [ ${#fallback[@]} -gt 0 ] && [ -f "$out/404.html" ]; then
  map=$(IFS=,; echo "${fallback[*]}")
  script="<script>(function(){var m=[$map];for(var i=0;i<m.length;i++){if(location.pathname.indexOf(m[i][0])===0){location.replace(m[i][1]);return;}}})();</script>"
  SCRIPT="$script" perl -0pi -e 's|</body>|$ENV{SCRIPT}\n</body>|' "$out/404.html"
fi

mkdir -p "$out/docs"
jq '{packages: .}' <<< "$versions" > "$out/docs/versions.json"

{
  echo '<?xml version="1.0" encoding="UTF-8"?>'
  echo '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">'
  sed 's|.*|  <url><loc>&</loc></url>|' "$sitemap"
  echo '</urlset>'
} > "$out/sitemap.xml"
printf 'User-agent: *\nAllow: /\nSitemap: %s/sitemap.xml\n' "$site_url" > "$out/robots.txt"

echo "Published: $(jq -c '[.[] | {name, version, majors: [.majors[].version]}]' <<< "$versions")"
