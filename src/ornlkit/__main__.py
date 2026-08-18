"""Allow running with `python -m ornlkit` or `uv run ornlkit`."""

from ornlkit import __version__


def main() -> None:
    print(f"Hello from ornlkit {__version__}")


if __name__ == "__main__":
    main()
