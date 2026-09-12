#!/usr/bin/env bash
# dart/flutter analyze 告警基线比对：只允许减少，不允许新增。
#
# 用法:
#   scripts/check_analyze.sh             # 与 scripts/analyze_baseline.txt 比对
#   scripts/check_analyze.sh --update    # 以当前结果重写基线
#
# 背景: 仓库历史遗留 1100+ 条 info/warning，一次性清零不现实；
#       基线用于防止新增告警混入（P0-2 第 3 项）。
#       若因 Flutter SDK 升级导致告警文本变化，经确认后执行 --update 刷新基线。
# 注意: 基线在 git-crypt 已解锁（或本地桩 config.dart）状态下生成；
#       加密态 config.dart 会引入 4 条 URI/符号错误，属环境差异。
set -euo pipefail

cd "$(dirname "$0")/.."

BASELINE="scripts/analyze_baseline.txt"
RAW="$(mktemp)"
CURRENT="$(mktemp)"
trap 'rm -f "$RAW" "$CURRENT"' EXIT

# 优先用 PATH 上的 dart；找不到时从 flutter 位置推导（如 ~/development/flutter）
DART_BIN=${DART_BIN:-$(command -v dart || true)}
if [[ -z "$DART_BIN" ]]; then
  FLUTTER_BIN=$(command -v flutter) || {
    echo "dart/flutter 不在 PATH 上" >&2
    exit 127
  }
  DART_BIN="$(dirname "$FLUTTER_BIN")/dart"
fi

# dart analyze 退出码: 0=无告警, 2=有 info/warning, 3=有 error；其余视为工具故障
set +e
"$DART_BIN" analyze --format machine > "$RAW" 2>/dev/null
code=$?
set -e
if [[ $code -ne 0 && $code -ne 2 ]]; then
  echo "dart analyze 异常退出 (code=$code)：" >&2
  if [[ $code -eq 3 ]]; then
    echo "存在 error 级问题：" >&2
    grep '^ERROR' "$RAW" | head -20 >&2
  else
    head -20 "$RAW" >&2
  fi
  exit 1
fi

python3 scripts/parse_analyze_machine.py < "$RAW" | LC_ALL=C sort > "$CURRENT"

if [[ "${1:-}" == "--update" ]]; then
  cp "$CURRENT" "$BASELINE"
  echo "基线已更新: $(wc -l < "$BASELINE" | tr -d ' ') 条"
  exit 0
fi

if (( $(wc -l < "$CURRENT" | tr -d ' ') == 0 )); then
  echo "✓ dart analyze 无任何告警"
  exit 0
fi

new_count="$(comm -13 "$BASELINE" "$CURRENT" | grep -c . || true)"
if (( new_count > 0 )); then
  echo "✗ analyze 新增了 ${new_count} 条告警（基线 $(wc -l < "$BASELINE" | tr -d ' ') 条）："
  comm -13 "$BASELINE" "$CURRENT" | sed 's/^/  + /'
  exit 1
fi
echo "✓ 无新增告警（基线 $(wc -l < "$BASELINE" | tr -d ' ') 条）"
