#!/usr/bin/env bash
# Build Netlify : installe Flutter (canal stable) puis compile le web. Voir netlify.toml.
set -euo pipefail
FLUTTER_DIR="${HOME}/flutter"
if [ ! -x "$FLUTTER_DIR/bin/flutter" ]; then
  git clone --depth 1 -b stable https://github.com/flutter/flutter.git "$FLUTTER_DIR"
fi
export PATH="$FLUTTER_DIR/bin:$PATH"
flutter config --no-analytics >/dev/null 2>&1 || true
flutter pub get
bash tool/build_web.sh
