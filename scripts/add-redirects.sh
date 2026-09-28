#!/usr/bin/env bash
# Adds redirects from the old documentation URLs to the built site
# (cucumberswift/CucumberSwift#176).
#
#   scripts/add-redirects.sh _site
#
# Each package now publishes its own docs to its own Pages site, which GitHub
# serves under this domain:
#
#   /CucumberSwift/             and /CucumberSwift/X.x/
#   /CucumberSwiftExpressions/  and /CucumberSwiftExpressions/X.x/
#
# This site served them before, under /help/ and, until #161, under /docs/. Each
# page it served now redirects to the same page on the package's site:
#
#   /help/<page>, /docs/<page>                         → /CucumberSwift/<page>
#   /help/5.x/<page>, /docs/5.x/<page>                 → /CucumberSwift/5.x/<page>
#   /help/expressions/<page>, /docs/expressions/<page> → /CucumberSwiftExpressions/<page>
#   /documentation/<page>, /tutorials/<page>           → /CucumberSwift/<page>
#
# The pages are listed in redirects/<package>.txt. The lists are fixed: they are
# the pages of the last docs this site served (5.0.11 and 0.0.9), and no new page
# will ever appear under the old URLs. Anything else under an old path is sent to
# its package's documentation by 404.html.
#
# It also writes /help/versions.json and /docs/versions.json from the packages'
# own versions.json, sitemap.xml for the website, and robots.txt listing the
# website's and the packages' sitemaps.
#
# Needs curl, jq and perl. It calls no GitHub API and uses no token. A failed
# download stops the script, so a site with a missing file is never deployed.
set -euo pipefail

out=${1:?usage: add-redirects.sh <site directory>}
site_url=${SITE_URL:-https://cucumberswift.org}
lists=$(cd "$(dirname "$0")/../redirects" && pwd)

# package | DocC module | majors | old paths (space separated; "-" is the site root)
packages=(
  "CucumberSwift|cucumberswift|5.x|help docs -"
  "CucumberSwiftExpressions|cucumberswiftexpressions|0.x|help/expressions docs/expressions"
)

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

fallback=()
versions='[]'
count=0

for package in "${packages[@]}"; do
  IFS='|' read -r name module majors olds <<< "$package"
  home="/$name/documentation/$module/"
  list="$lists/$name.txt"
  echo "== /$name/"

  for old in $olds; do
    if [ "$old" = "-" ]; then
      # The site root only ever held /documentation/ and /tutorials/, never an index or a major.
      while read -r page; do
        redirect_page "$out/${page}index.html" "/$name/$page"
        count=$((count + 1))
      done < "$list"
      fallback+=("[\"/documentation/\", \"$home\"]" "[\"/tutorials/\", \"$home\"]")
      continue
    fi
    for base in "" $majors; do
      from="$out/$old/${base:+$base/}"
      to="/$name/${base:+$base/}"
      while read -r page; do
        redirect_page "$from${page}index.html" "$to$page"
        count=$((count + 1))
      done < "$list"
      # The index of each old path goes straight to the documentation page, not to a second redirect.
      redirect_page "${from}index.html" "${to}documentation/$module/"
      count=$((count + 1))
    done
    fallback+=("[\"/$old/\", \"$home\"]")
  done

  versions=$(jq -c --argjson v "$(curl -fsSL --max-time 30 "$site_url/$name/versions.json")" '. + [$v]' <<< "$versions")
done

# Old pages that are not in the lists go to their package's documentation.
# Most specific first, so /help/expressions/ is matched before /help/.
map=$(printf '%s\n' "${fallback[@]}" | awk -F'"' '{ print length($2) "\t" $0 }' | sort -rn | cut -f2- | paste -sd, -)
script="<script>(function(){var m=[$map];for(var i=0;i<m.length;i++){if(location.pathname.indexOf(m[i][0])===0){location.replace(m[i][1]);return;}}})();</script>"
SCRIPT="$script" perl -0pi -e 's|</body>|$ENV{SCRIPT}\n</body>|' "$out/404.html"

# Kept for anyone who read the published versions here. Refreshed on each deploy.
mkdir -p "$out/help" "$out/docs"
jq '{packages: .}' <<< "$versions" > "$out/help/versions.json"
cp "$out/help/versions.json" "$out/docs/versions.json"

{
  echo '<?xml version="1.0" encoding="UTF-8"?>'
  echo '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">'
  echo "  <url><loc>$site_url/</loc></url>"
  echo '</urlset>'
} > "$out/sitemap.xml"
{
  printf 'User-agent: *\nAllow: /\n'
  printf 'Sitemap: %s/sitemap.xml\n' "$site_url"
  for package in "${packages[@]}"; do
    printf 'Sitemap: %s/%s/sitemap.xml\n' "$site_url" "${package%%|*}"
  done
} > "$out/robots.txt"

echo "Wrote $count redirect pages. Published: $(jq -c '[.[] | {name, version}]' <<< "$versions")"
