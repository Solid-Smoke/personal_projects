# Converts all images of given source extensions into another format safely
bulk_iconvert() {

  BULK_ICONVERT_VERSION="v1.0.1"

  local src_pattern="$1"   # e.g. "jpg|jpeg|png"
  local dst="$2"           # e.g. "webp"

  if [ -z "$src_pattern" ] || [ -z "$dst" ]; then
    echo "Usage: bulk_iconvert png|jpg|... webp"
    return 1
  fi

  # Find and convert files
  echo -e "Bulk Image Converter $BULK_ICONVERT_VERSION"
  find . -type f -regextype posix-extended -iregex ".*\.(${src_pattern})$" \
    -exec sh -c '
      for infile; do
        dir="$(dirname "$infile")"
        base="$(basename "${infile%.*}")"
        outfile="$dir/$base.'"$dst"'"
        if [ -f "$outfile" ]; then
          echo "Skipping existing file: $outfile"
        else
          if convert "$infile" "$outfile"; then
            echo "Converted: $infile → $outfile"
          else
            echo "Failed: $infile"
          fi
        fi
      done
    ' sh {} +
}

