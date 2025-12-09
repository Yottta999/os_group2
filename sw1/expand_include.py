#!/usr/bin/env python3
import os
import re
import sys

include_re = re.compile(r'^\s*\.include\s+"([^"]+)"')

def expand_file(path, included=None):
    if included is None:
        included = set()

    # 無限再帰防止
    abs_path = os.path.abspath(path)
    if abs_path in included:
        raise RuntimeError(f"Recursive include detected: {path}")
    included.add(abs_path)

    out_lines = []

    base_dir = os.path.dirname(abs_path)

    with open(abs_path, 'r', encoding='utf-8') as f:
        for line in f:
            m = include_re.match(line)
            if m:
                inc_path = os.path.join(base_dir, m.group(1))
                out_lines.append(f"/* ---- begin include {m.group(1)} ---- */\n")
                out_lines.extend(expand_file(inc_path, included))
                out_lines.append(f"/*; ---- end include {m.group(1)} ----*/\n\n")
            else:
                out_lines.append(line)

    return out_lines


def main():
    if len(sys.argv) < 2:
        print("Usage: expand_inc.py input.s > output.s")
        return

    path = sys.argv[1]
    sys.stdout.writelines(expand_file(path))


if __name__ == "__main__":
    main()
