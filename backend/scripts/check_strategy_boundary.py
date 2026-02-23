from __future__ import annotations

import argparse
import sys
from datetime import datetime
from pathlib import Path
from zoneinfo import ZoneInfo

ROOT_DIR = Path(__file__).resolve().parents[1]
if str(ROOT_DIR) not in sys.path:
    sys.path.insert(0, str(ROOT_DIR))

from services.scoring_service import get_strategy_status, validate_strategy_request

KST = ZoneInfo("Asia/Seoul")


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Manual boundary check for premarket/close strategy windows.")
    parser.add_argument(
        "--date",
        dest="session_date",
        default=datetime.now(KST).date().isoformat(),
        help="Session date in YYYY-MM-DD (default: today in KST).",
    )
    return parser.parse_args()


def main() -> int:
    args = _parse_args()
    checkpoints = ["07:59:59", "08:00:00", "15:29:59", "15:30:00"]

    print(f"Strategy boundary check date={args.session_date} timezone=Asia/Seoul")
    for hhmmss in checkpoints:
        now_kst = datetime.fromisoformat(f"{args.session_date}T{hhmmss}+09:00")
        status = get_strategy_status(requested_date_str=args.session_date, now_kst_value=now_kst)
        auto = validate_strategy_request(
            requested_strategy=None,
            requested_date_str=args.session_date,
            now_kst_value=now_kst,
        )
        explicit_premarket = validate_strategy_request(
            requested_strategy="premarket",
            requested_date_str=args.session_date,
            now_kst_value=now_kst,
        )
        explicit_close = validate_strategy_request(
            requested_strategy="close",
            requested_date_str=args.session_date,
            now_kst_value=now_kst,
        )

        print(f"\n[{hhmmss}]")
        print(
            f"- available={status.get('availableStrategies')} default={status.get('defaultStrategy')} "
            f"statusError={status.get('errorCode')}"
        )
        print(
            f"- auto strategy={auto.get('strategy')} signalDate={auto.get('signalDate')} "
            f"error={auto.get('errorCode')}"
        )
        print(
            f"- explicit premarket: strategy={explicit_premarket.get('strategy')} "
            f"error={explicit_premarket.get('errorCode')}"
        )
        print(
            f"- explicit close: strategy={explicit_close.get('strategy')} "
            f"error={explicit_close.get('errorCode')}"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
