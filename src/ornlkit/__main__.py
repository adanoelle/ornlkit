"""Allow running with `python -m ornlkit` or `uv run ornlkit`."""

import logging
import sys

from ornlkit import __version__
from ornlkit.diagnostics import log_diagnostics

logging.basicConfig(
    stream=sys.stdout,
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s: %(message)s",
    datefmt="%Y-%m-%dT%H:%M:%S",
)
logger = logging.getLogger(__name__)


def main() -> None:
    log_diagnostics()
    logger.info("Hello from ornlkit %s", __version__)


if __name__ == "__main__":
    main()
