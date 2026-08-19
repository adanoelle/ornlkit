"""Allow running with `python -m ornlkit` or `uv run ornlkit`."""

import logging

from omegaconf import DictConfig

from ornlkit import __version__
from ornlkit.experiment import ornlkit_main

logger = logging.getLogger(__name__)


@ornlkit_main(config_path="conf", config_name="config")
def main(cfg: DictConfig) -> None:
    logger.info("%s %s", cfg.app.greeting, __version__)


if __name__ == "__main__":
    main()
