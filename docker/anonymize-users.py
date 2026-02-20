#!/usr/bin/env python3
"""
Anonymize a WP user export CSV for use as test data.

Reads the full user export, strips PII, and outputs a CSV compatible
with `wp user import-csv`.

Usage:
    python3 anonymize-users.py
"""

import csv
import os
from collections import Counter

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_DIR = os.path.dirname(SCRIPT_DIR)

INPUT_CSV = os.path.join(
    PROJECT_DIR,
    "data export",
    "user_export_2026-02-20-10-44-46.csv",
)
OUTPUT_CSV = os.path.join(SCRIPT_DIR, "test-users.csv")

OUTPUT_FIELDS = [
    "user_login",
    "user_email",
    "display_name",
    "first_name",
    "last_name",
    "user_pass",
    "role",
]


def primary_role(roles_value):
    """Extract the first/primary role from a (possibly multi-valued) roles field."""
    raw = roles_value.strip()
    if not raw:
        return ""
    # Roles may be separated by ", " or "," — take the first one.
    return raw.split(",")[0].strip()


def main():
    role_counts = Counter()
    seq = 0
    skipped_no_email = 0

    with (
        open(INPUT_CSV, newline="", encoding="utf-8") as infile,
        open(OUTPUT_CSV, "w", newline="", encoding="utf-8") as outfile,
    ):
        reader = csv.DictReader(infile)
        writer = csv.DictWriter(outfile, fieldnames=OUTPUT_FIELDS)
        writer.writeheader()

        for row in reader:
            email = row["user_email"].strip()
            if not email:
                skipped_no_email += 1
                continue

            seq += 1
            tag = f"{seq:04d}"
            role = primary_role(row["roles"])
            role_counts[role] += 1

            first_name = f"Test{seq}"
            last_name = f"User{seq}"

            writer.writerow(
                {
                    "user_login": f"user_{tag}",
                    "user_email": f"user_{tag}@example.com",
                    "display_name": f"{first_name} {last_name}",
                    "first_name": first_name,
                    "last_name": last_name,
                    "user_pass": "testpass123",
                    "role": role,
                }
            )

    # Summary
    total = seq
    print(f"Input:   {INPUT_CSV}")
    print(f"Output:  {OUTPUT_CSV}")
    print(f"Total users written: {total}")
    if skipped_no_email:
        print(f"Skipped (no email):  {skipped_no_email}")
    print()
    print("Role distribution:")
    for role, count in role_counts.most_common():
        label = role if role else "(empty)"
        print(f"  {count:4d}  {label}")


if __name__ == "__main__":
    main()
