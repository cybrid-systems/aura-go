#!/usr/bin/env python3
"""Host-side MiniMax proposer for aura-go.

HTTP stays here. Soft only reads the lambda file this script writes and
gates it (set!/caps/display/mutate/eval/load/shell/http are Soft's job).

Config: $MINIMAX_ENV_FILE or ~/.config/aura-build/minimax.env
  MINIMAX_API_KEY_FILE, MINIMAX_BASE_URL, MINIMAX_MODEL

Usage: propose_minimax.py OUT_PATH [COLOR [ROUND [NOTE [PREV_PATH]]]]
  COLOR is 1 (black) or 2 (white); default 1.
  ROUND / NOTE / PREV_PATH are evolution context (previous lambda path).
Stdout stays empty. Stderr is PROPOSE_WROTE or PROPOSE_FAIL <reason>.
The API key is never printed.
"""
from __future__ import annotations

import json
import os
import re
import sys
import urllib.error
import urllib.request
from pathlib import Path


def _env_file() -> Path | None:
    raw = os.environ.get("MINIMAX_ENV_FILE", "").strip()
    candidates = []
    if raw:
        candidates.append(Path(raw))
    candidates.append(Path.home() / ".config" / "aura-build" / "minimax.env")
    candidates.append(Path("/home/box/.config/aura-build/minimax.env"))
    for p in candidates:
        if p.is_file():
            return p
    return None


def _parse_env(path: Path) -> dict[str, str]:
    out: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, _, v = line.partition("=")
        out[k.strip()] = v.strip().strip('"').strip("'")
    return out


def _read_key(env: dict[str, str], env_path: Path) -> str:
    key = os.environ.get("MINIMAX_API_KEY", "").strip()
    if key:
        return key
    file_raw = env.get("MINIMAX_API_KEY_FILE", "").strip()
    candidates = []
    if file_raw:
        candidates.append(Path(file_raw))
        candidates.append(env_path.parent / Path(file_raw).name)
    candidates.append(env_path.parent / "minimax_api_key")
    for p in candidates:
        if p.is_file():
            return p.read_text(encoding="utf-8").strip()
    return ""


def _redact(text: str, key: str) -> str:
    if key and key in text:
        text = text.replace(key, "[redacted]")
    return text


def _balanced(s: str) -> bool:
    n = 0
    for ch in s:
        if ch == "(":
            n += 1
        elif ch == ")":
            n -= 1
            if n < 0:
                return False
    return n == 0


def _extract_lambda(text: str) -> str:
    if not text:
        return ""
    fence = re.search(r"```(?:aura|scheme|lisp)?\s*([\s\S]*?)```", text, re.I)
    body = fence.group(1) if fence else text
    start = body.find("(lambda")
    if start < 0:
        return ""
    n = 0
    end = -1
    for i, ch in enumerate(body[start:], start):
        if ch == "(":
            n += 1
        elif ch == ")":
            n -= 1
            if n == 0:
                end = i + 1
                break
    if end < 0:
        return ""
    line = " ".join(body[start:end].split())
    if not line.startswith("(lambda") or "board" not in line or "color" not in line:
        return ""
    if not _balanced(line):
        return ""
    return line


def _prompt(side: str, color: int, rnd: int, note: str, prev: str) -> str:
    if color == 1:
        goal = (
            "Black place-fn: rank capture-band features (board > 9999) above "
            "everything else, then liberty-saves (board > 99), then the rest. "
            "Use a coefficient that includes the round number so this is not "
            "a copy of a previous line."
        )
        example = "(lambda (board color) (if (number? board) (if (> board 9999) (* board 2) board) 0))"
    else:
        goal = (
            "White place-fn: rank liberty-saves (board > 99 and board < 10000) "
            "above raw captures. A capture-band feature may score lower than "
            "a liberty-save. Use a coefficient that includes the round number."
        )
        example = "(lambda (board color) (if (number? board) (if (> board 9999) board (if (> board 99) (* board 3) board)) 0))"
    prev_s = prev.strip() if prev else "none"
    return (
        "Return ONLY one Aura line of the form (lambda (board color) <expr>). "
        f"You are proposing a {side} Go place-fn for round {rnd}. "
        "board is a packed integer feature, not a coordinate. "
        "color is 1 or 2. Expr must return a number (higher is better). "
        "ONLY use: board, color, number?, if, +, -, *, <, >, =, and parentheses. "
        "Do NOT use and, or, mod, modulo, floor, quotient, /, set!, caps, display, "
        "mutate, eval, load, shell, or http. No markdown. "
        f"{goal} "
        f"Previous lambda (do not repeat it verbatim): {prev_s}. "
        f"Last match note: {note}. "
        f"Shape example only, change the numbers: {example}"
    )


def _call(base: str, key: str, model: str, prompt: str, temperature: float) -> str:
    body = {
        "model": model,
        "messages": [
            {"role": "system", "content": "You output a single Aura lambda and nothing else."},
            {"role": "user", "content": prompt},
        ],
        "temperature": temperature,
        "max_tokens": 256,
        "thinking": {"type": "disabled"},
    }
    req = urllib.request.Request(
        f"{base}/chat/completions",
        data=json.dumps(body).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {key}",
            "Content-Type": "application/json",
            "Accept": "application/json",
        },
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=60) as resp:
        payload = json.loads(resp.read().decode("utf-8"))
    return str(payload["choices"][0]["message"]["content"] or "")


def main() -> int:
    if len(sys.argv) < 2 or len(sys.argv) > 6:
        print("PROPOSE_FAIL usage", file=sys.stderr)
        return 2
    out = Path(sys.argv[1])
    color = 1
    rnd = 1
    note = "none"
    prev = ""
    if len(sys.argv) >= 3:
        try:
            color = int(sys.argv[2])
        except ValueError:
            color = 1
    if len(sys.argv) >= 4:
        try:
            rnd = int(sys.argv[3])
        except ValueError:
            rnd = 1
    if len(sys.argv) >= 5:
        note = sys.argv[4].replace("\n", " ")[:180]
    if len(sys.argv) >= 6 and sys.argv[5]:
        pp = Path(sys.argv[5])
        if pp.is_file():
            prev = " ".join(pp.read_text(encoding="utf-8").split())
    side = "black" if color == 1 else "white"
    env_path = _env_file()
    if env_path is None:
        print("PROPOSE_FAIL no_env", file=sys.stderr)
        return 1
    env = _parse_env(env_path)
    key = _read_key(env, env_path)
    if not key:
        print("PROPOSE_FAIL no_key", file=sys.stderr)
        return 1
    base = (
        os.environ.get("MINIMAX_BASE_URL", "").strip()
        or env.get("MINIMAX_BASE_URL", "").strip()
        or "https://api.minimax.cn/v1"
    ).rstrip("/")
    model = (
        os.environ.get("MINIMAX_MODEL", "").strip()
        or env.get("MINIMAX_MODEL", "").strip()
        or "MiniMax-M3"
    )
    prompt = _prompt(side, color, rnd, note, prev)
    banned = ("set!", "vector-set!", "mod", "modulo", "floor", "quotient",
              "/", "caps", "display", "mutate", "eval", "load", "shell", "http",
              " and ", " or ")
    lam = ""
    last_fail = "no_lambda"
    for attempt, temp in ((1, 0.4), (2, 0.8)):
        try:
            content = _call(base, key, model, prompt, temp)
        except urllib.error.HTTPError as exc:
            err = exc.read().decode("utf-8", errors="replace")[:300]
            print("PROPOSE_FAIL http_" + str(exc.code) + " " + _redact(err, key), file=sys.stderr)
            return 1
        except Exception as exc:  # noqa: BLE001
            print("PROPOSE_FAIL " + _redact(type(exc).__name__, key), file=sys.stderr)
            return 1
        cand = _extract_lambda(content)
        if not cand.startswith("(lambda"):
            last_fail = "no_lambda"
            continue
        low = cand.lower()
        bad = ""
        for b in banned:
            if b.lower() in low:
                if b == "/" and (" / " not in cand and "(/" not in cand):
                    continue
                bad = b
                break
        if bad:
            last_fail = "banned_" + bad.replace("!", "").strip()
            continue
        if prev and cand == prev:
            last_fail = "repeat"
            prompt = prompt + " The previous attempt was rejected because it repeated the prior lambda. Change a coefficient."
            continue
        lam = cand
        break
    if not lam:
        print("PROPOSE_FAIL " + last_fail, file=sys.stderr)
        return 1
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(lam + "\n", encoding="utf-8")
    print("PROPOSE_WROTE", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
