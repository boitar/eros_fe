#!/usr/bin/env python3
"""dart analyze --format machine 输出 → 稳定告警签名（一行一条）。

输入行格式: SEVERITY|TYPE|CODE|ABS_PATH|LINE|COL|LENGTH|MESSAGE
签名 = SEVERITY|CODE|相对路径|MESSAGE
忽略行列号，避免无关代码位移造成基线误报。
"""
import os
import sys


def main() -> int:
    root = os.getcwd()
    for raw in sys.stdin:
        line = raw.rstrip('\n')
        if not line:
            continue
        parts = line.split('|', 7)
        if len(parts) != 8:
            continue
        severity, _type, code, path, _line, _col, _len, message = parts
        rel = os.path.relpath(path, root)
        print(f"{severity}|{code}|{rel}|{message}")
    return 0


if __name__ == '__main__':
    sys.exit(main())
