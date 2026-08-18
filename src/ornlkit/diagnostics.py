"""Diagnostic logging for verifying compute-job environments."""

import importlib.metadata
import logging
import os
import platform
import shutil
import sys
import time

logger = logging.getLogger(__name__)

_CORE_PACKAGES = ("polars", "pyarrow", "datafusion", "pydantic", "orjson", "rustworkx")

_SLURM_VARS = (
    "SLURM_JOB_ID",
    "SLURM_NODELIST",
    "SLURM_NNODES",
    "SLURM_NTASKS",
    "SLURM_CLUSTER_NAME",
)


def _get_package_version(name: str) -> str:
    """Return the installed version of *name*, or 'NOT FOUND'."""
    try:
        return importlib.metadata.version(name)
    except importlib.metadata.PackageNotFoundError:
        return "NOT FOUND"


def log_diagnostics() -> None:
    """Log environment information useful for verifying compute jobs."""
    t0 = time.monotonic()

    logger.info("--- environment diagnostics ---")
    logger.info("hostname: %s", platform.node())
    logger.info("platform: %s", platform.platform())
    logger.info("python: %s (%s)", platform.python_version(), sys.executable)
    logger.info("cwd: %s", os.getcwd())
    logger.info("user: %s", os.environ.get("USER", "unknown"))

    # SLURM variables (only logged when present)
    slurm_vars = {k: os.environ[k] for k in _SLURM_VARS if k in os.environ}
    if slurm_vars:
        for k, v in slurm_vars.items():
            logger.info("%s: %s", k, v)
    else:
        logger.info("SLURM: not running inside a job")

    # uv availability
    uv_path = shutil.which("uv")
    logger.info("uv: %s", uv_path or "not found on PATH")

    # Core dependency versions
    for pkg in _CORE_PACKAGES:
        logger.info("%s: %s", pkg, _get_package_version(pkg))

    elapsed = time.monotonic() - t0
    logger.info("diagnostics completed in %.3f s", elapsed)
    logger.info("--- end diagnostics ---")
