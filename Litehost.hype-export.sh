#!/bin/bash
#
# Litehost export script for Tumult Hype
# Adds "Litehost" to File > Export as HTML5. Hype exports the document, this
# script zips it, uploads it to Litehost and gives you a link that opens in any
# browser. No account needed to try it; sign in to keep the link.
#
# Install: copy this file to ~/Library/Application Scripts/com.tumult.Hype4/
# (Hype > Settings > Export opens this folder) and run: chmod 755 Litehost.hype-export.sh
#
# Source and help: https://litehost.io/guides/send-hype-animation-to-client
# Version 1

API_URL="https://connect.litehost.io/v1/projects/temp"
MAX_BYTES=$((2 * 1024 * 1024))

result() {
  echo "===================="
  echo "{\"result\": $1}"
  exit 0
}

# "True"/"False" from Hype -> JSON booleans
json_bool() {
  if [ "$1" = "True" ] || [ "$1" = "true" ]; then echo true; else echo false; fi
}

# Escape a string for JSON
json_str() {
  local s=${1//\\/\\\\}
  s=${s//\"/\\\"}
  printf '"%s"' "$s"
}

# Read data.<key> from the upload response
json_get() {
  /usr/bin/osascript -l JavaScript -e 'function run(a){try{var j=JSON.parse(a[0]);var v=a[1]==="error"?j.error:(j.data&&j.data[a[1]]);return v?String(v):""}catch(e){return ""}}' "$1" "$2"
}

dialog() {
  # $1 message, $2 buttons (AppleScript list), $3 default button
  if [ -n "$LITEHOST_TEST" ]; then echo "DIALOG: $1" >&2; return; fi
  /usr/bin/osascript -e "display dialog \"$1\" with title \"Litehost\" buttons {$2} default button \"$3\"" -e 'button returned of result' 2>/dev/null
}

MODE=""
REPLACE_URL=""; URL_TYPE=""; IS_REFERENCE="False"; SHOULD_PRELOAD=""
STAGING=""; DESTINATION=""; IS_PREVIEW="False"

while [ $# -gt 0 ]; do
  case "$1" in
    --get_options) MODE="get_options" ;;
    --check_for_updates) MODE="check_for_updates" ;;
    --replace_url) MODE="replace_url"; REPLACE_URL="$2"; shift ;;
    --url_type) URL_TYPE="$2"; shift ;;
    --is_reference) IS_REFERENCE="$2"; shift ;;
    --should_preload) SHOULD_PRELOAD="$2"; shift ;;
    --modify_staging_path) MODE="modify_staging_path"; STAGING="$2"; shift ;;
    --destination_path) DESTINATION="$2"; shift ;;
    --is_preview) IS_PREVIEW="$2"; shift ;;
    --*) shift ;;  # other arguments carry a value we don't use
  esac
  shift
done

case "$MODE" in
  get_options)
    result '{
      "export_options": {
        "exportShouldInlineHypeJS": false,
        "exportShouldInlineDocumentLoader": false,
        "exportShouldSaveHTMLFile": true,
        "exportShouldNameAsIndexDotHTML": true,
        "exportShouldBustBrowserCaching": true
      },
      "save_options": {
        "file_extension": "zip",
        "allows_export": true,
        "allows_preview": false
      },
      "document_arguments": [],
      "extra_actions": [],
      "min_hype_build_version": "574"
    }'
    ;;

  replace_url)
    # Keep Hype's own URLs and folder layout.
    out="{\"url\": $(json_str "$REPLACE_URL"), \"is_reference\": $(json_bool "$IS_REFERENCE")"
    if [ -n "$SHOULD_PRELOAD" ] && [ "$SHOULD_PRELOAD" != "None" ]; then
      out="$out, \"should_preload\": $(json_bool "$SHOULD_PRELOAD")"
    fi
    result "$out}"
    ;;

  modify_staging_path)
    [ -d "$STAGING" ] || result false
    # Absolute path, since we zip from inside the staging folder
    DESTINATION="$(cd "$(dirname "$DESTINATION")" && pwd)/$(basename "$DESTINATION")"
    rm -rf "$DESTINATION"
    if [ "$(json_bool "$IS_PREVIEW")" = true ]; then
      mv "$STAGING" "$DESTINATION"
      result true
    fi

    # Zip the export (also kept on disk at the place you picked in Hype).
    (cd "$STAGING" && /usr/bin/zip -q -r -X "$DESTINATION" . -x ".DS_Store" -x "*/.DS_Store") || result false

    size=$(/usr/bin/stat -f%z "$DESTINATION" 2>/dev/null || /usr/bin/stat -c%s "$DESTINATION")
    if [ "$size" -gt "$MAX_BYTES" ]; then
      mb=$(echo "scale=1; $size / 1048576" | /usr/bin/bc)
      choice=$(dialog "This export is $mb MB. Uploads without an account are limited to 2 MB.\n\nThe zip is saved where you exported it. Sign in to Litehost and upload it there (free account: up to 5 MB)." '"Close", "Open Litehost"' "Open Litehost")
      [ "$choice" = "Open Litehost" ] && /usr/bin/open "https://litehost.io/dashboard?utm_source=hype_export"
      result true
    fi

    response=$(/usr/bin/curl -sS --max-time 120 -F "files=@$DESTINATION;type=application/zip" "$API_URL" 2>&1)
    url=$(json_get "$response" url)
    claim=$(json_get "$response" claimUrl)

    if [ -z "$url" ]; then
      err=$(json_get "$response" error)
      case "$err" in
        *"limited to"*"files"*)
          choice=$(dialog "This export has more files than Litehost accepts without an account.\n\nThe zip is saved where you exported it. Sign in to Litehost and upload it there (free account)." '"Close", "Open Litehost"' "Open Litehost")
          [ "$choice" = "Open Litehost" ] && /usr/bin/open "https://litehost.io/dashboard?utm_source=hype_export"
          result true
          ;;
      esac
      [ -z "$err" ] && err="Could not reach Litehost. Check your connection and try again."
      err=${err//\"/\'}
      dialog "Upload failed: $err\n\nThe zip is saved where you exported it." '"OK"' "OK" >/dev/null
      result true
    fi

    if [ -n "$LITEHOST_TEST" ]; then echo "URL=$url CLAIM=$claim" >&2; result true; fi
    printf '%s' "$url" | /usr/bin/pbcopy
    choice=$(dialog "Your animation is online:\n$url\n\nThe link is copied. It stays online for 15 minutes. To keep it, sign in with Google or email (free)." '"Open link", "Keep this link"' "Keep this link")
    if [ "$choice" = "Keep this link" ]; then
      /usr/bin/open "$claim"
    elif [ "$choice" = "Open link" ]; then
      /usr/bin/open "$url"
    fi
    result true
    ;;

  check_for_updates)
    exit 0
    ;;
esac

exit 0
