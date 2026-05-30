#!/usr/bin/env python3
"""
gen_profile.py — Generate a random fictional profile.

Uses curated fictional character names (anime or custom YAML list)
combined with real geographic data and cryptographically secure randomness.
"""

from __future__ import annotations

import argparse
import calendar
import datetime
import json
import logging
import secrets
import string
from pathlib import Path

import geonamescache
import yaml

__version__ = "1.1.0"

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
logging.basicConfig(level=logging.INFO, format="[%(levelname)s] %(message)s")
logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Generate a random profile using curated fictional character names. "
            "You may use your own character list if desired."
        ),
        formatter_class=argparse.RawTextHelpFormatter,
    )

    parser.add_argument(
        "--version", action="version", version=f"%(prog)s {__version__}"
    )

    parser.add_argument(
        "--names",
        default="/etc/anime_names/anime_characters.yaml",
        metavar="PATH",
        help="Path to YAML file containing character names (default: %(default)s)",
    )

    parser.add_argument(
        "--username-length",
        type=int,
        default=10,
        metavar="N",
        help="Username length, minimum 1 (default: %(default)s)",
    )

    parser.add_argument(
        "--with-password",
        action="store_true",
        help="Generate a random password",
    )

    parser.add_argument(
        "--password-length",
        type=int,
        metavar="N",
        help="Password length, minimum 4 (requires --with-password, default: 64)",
    )

    parser.add_argument(
        "--no-password-symbols",
        dest="password_symbols",
        action="store_false",
        help="Disable symbols in generated password",
    )
    parser.set_defaults(password_symbols=True)

    parser.add_argument(
        "--show-password",
        action="store_true",
        help="Display generated password in stdout output",
    )

    parser.add_argument(
        "--save",
        metavar="PATH",
        help="Output file path to save the generated profile",
    )

    parser.add_argument(
        "--format",
        choices=["text", "json"],
        help="Output format (requires --save; inferred from extension if omitted)",
    )

    parser.add_argument(
        "--country",
        metavar="NAME",
        help="Specify a country name; otherwise a random one is selected",
    )

    parser.add_argument(
        "--quiet",
        action="store_true",
        help="Suppress stdout profile output (useful with --save)",
    )

    args = parser.parse_args()

    # Infer format from file extension
    if args.save and not args.format:
        match Path(args.save).suffix.lower():
            case ".json":
                args.format = "json"
            case ".txt":
                args.format = "text"
            case _:
                args.format = "text"

    # Enforce dependencies and value constraints
    if args.format and not args.save:
        parser.error("--format requires --save")

    if args.password_length is not None and not args.with_password:
        parser.error("--password-length requires --with-password")

    if args.username_length < 1:
        parser.error("--username-length must be at least 1")

    if args.password_length is not None and args.password_length < 4:
        parser.error("--password-length must be at least 4")

    if args.show_password and not args.with_password:
        parser.error("--show-password requires --with-password")

    return args


# ---------------------------------------------------------------------------
# Generators
# ---------------------------------------------------------------------------
def get_random_character(file_path: str) -> str:
    """Load a YAML character file and return a random character name."""
    with open(file_path, encoding="utf-8") as fh:
        data: dict[str, list[str]] = yaml.safe_load(fh)

    if not isinstance(data, dict) or not data:
        raise ValueError("Invalid or empty character file")

    title = secrets.choice(list(data.keys()))
    characters = data.get(title)

    if not characters:
        raise ValueError(f"Character list is empty for title: {title!r}")

    return secrets.choice(characters)


def generate_username(length: int) -> str:
    """Generate a cryptographically random alphanumeric username."""
    chars = string.ascii_letters + string.digits
    return secrets.choice(string.ascii_letters) + "".join(
        secrets.choice(chars) for _ in range(length - 1)
    )


def generate_password(length: int, with_symbols: bool = True) -> str:
    """
    Generate a cryptographically random password.

    Always contains at least one lowercase, one uppercase, one digit,
    and (when enabled) one symbol to satisfy common policy requirements.
    """
    symbols = r"!@#$%^&*()-_=+[]{};:,.<>?/|"
    charset = string.ascii_letters + string.digits + (symbols if with_symbols else "")

    # Guarantee policy-required character classes
    guaranteed = [
        secrets.choice(string.ascii_lowercase),
        secrets.choice(string.ascii_uppercase),
        secrets.choice(string.digits),
    ]
    if with_symbols:
        guaranteed.append(secrets.choice(symbols))

    remaining = length - len(guaranteed)
    pool = list(guaranteed) + [secrets.choice(charset) for _ in range(remaining)]
    secrets.SystemRandom().shuffle(pool)
    return "".join(pool)


def generate_birthdate() -> tuple[int, int, int]:
    """
    Return a random (day, month, year) tuple.

    Year range: 1962–2010. Day respects the actual number of days in
    the chosen month and year (including leap years).
    """
    year = secrets.randbelow(2010 - 1962 + 1) + 1962
    month = secrets.randbelow(12) + 1
    _, max_day = calendar.monthrange(year, month)
    day = secrets.randbelow(max_day) + 1
    return day, month, year


def calculate_age(day: int, month: int, year: int) -> int:
    """Calculate age correctly based on whether the birthday has passed this year."""
    today = datetime.date.today()
    age = today.year - year
    # Subtract 1 if the birthday hasn't occurred yet this year
    if (today.month, today.day) < (month, day):
        age -= 1
    return age


def get_random_country() -> str:
    """Return a random country name from the geonames dataset."""
    countries = geonamescache.GeonamesCache().get_countries_by_names()
    return secrets.choice(list(countries.keys()))


def get_random_city(country_name: str) -> str | None:
    """
    Return a random city name for the given country.

    Returns None if the country is not found; returns 'Unknown' if no
    cities are listed for a valid country.
    """
    geo = geonamescache.GeonamesCache()
    info = geo.get_countries_by_names().get(country_name.strip().title())

    if not info:
        logger.error("Unknown country: %r", country_name)
        return None

    country_code = info["iso"]
    cities = [
        city["name"]
        for city in geo.get_cities().values()
        if city["countrycode"] == country_code
    ]

    if not cities:
        logger.warning("No cities found for country: %r", country_name)
        return "Unknown"

    return secrets.choice(cities)


# ---------------------------------------------------------------------------
# Output helpers
# ---------------------------------------------------------------------------
def build_profile(
    name: str,
    username: str,
    birthdate: str,
    age: int,
    country: str,
    city: str,
    password: str | None,
    include_password: bool,
) -> dict[str, object]:
    """Assemble the profile dict, only storing password when explicitly allowed."""
    profile: dict[str, object] = {
        "name": name,
        "username": username,
        "birthdate": birthdate,
        "age": age,
        "country": country,
        "city": city,
    }
    if include_password and password is not None:
        profile["password"] = password
    return profile


def save_profile(path: str, fmt: str, profile: dict[str, object]) -> None:
    """Write the profile to disk in the requested format."""
    out = Path(path)
    out.parent.mkdir(parents=True, exist_ok=True)

    with out.open("w", encoding="utf-8") as fh:
        if fmt == "json":
            json.dump(profile, fh, indent=2, ensure_ascii=False)
            fh.write("\n")
        else:
            for key, value in profile.items():
                fh.write(f"{key}: {value}\n")

    logger.info("Profile saved → %s", path)


def print_profile(
    name: str,
    username: str,
    birthdate: str,
    age: int,
    country: str,
    city: str,
    password: str | None,
    show_password: bool,
) -> None:
    """Print the profile to stdout."""
    print(f"name:      {name}")
    print(f"username:  {username}")
    print(f"birthdate: {birthdate}")
    print(f"age:       {age}")
    print(f"country:   {country}")
    print(f"city:      {city}")

    if password is not None:
        if show_password:
            print(f"password:  {password}")
        else:
            print("password:  [hidden]")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main() -> None:
    args = parse_arguments()

    # ── Name ─────────────────────────────────────────────────────────────────
    names_path = Path(args.names)
    if names_path.is_file():
        try:
            name = get_random_character(str(names_path))
        except Exception as exc:
            logger.warning("Failed to load names file: %s — using random name", exc)
            name = generate_username(8)
    else:
        logger.warning("Name file not found at %r — using random name", args.names)
        name = generate_username(8)

    # ── Core fields ───────────────────────────────────────────────────────────
    username = generate_username(args.username_length)
    day, month, year = generate_birthdate()
    age = calculate_age(day, month, year)
    birthdate = f"{day:02d}/{month:02d}/{year}"

    country = args.country if args.country else get_random_country()
    city = get_random_city(country)
    if city is None:
        logger.error("Could not resolve a city for country %r — aborting", country)
        raise SystemExit(1)

    # ── Password ──────────────────────────────────────────────────────────────
    password: str | None = None
    if args.with_password:
        length = args.password_length if args.password_length else 64
        password = generate_password(length, with_symbols=args.password_symbols)

    # ── Stdout ────────────────────────────────────────────────────────────────
    if not args.quiet:
        print_profile(name, username, birthdate, age, country, city, password, args.show_password)

    # ── Save ──────────────────────────────────────────────────────────────────
    if args.save:
        profile = build_profile(
            name, username, birthdate, age, country, city,
            password, include_password=args.with_password,
        )
        save_profile(args.save, args.format or "text", profile)


if __name__ == "__main__":
    main()
