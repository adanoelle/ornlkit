"""Diagnostic logging for verifying compute-job environments."""

import importlib.metadata
import logging
import os
import platform
import shutil
import sys
import time
from collections.abc import Sequence

import orjson
from pydantic import BaseModel, Field

logger = logging.getLogger(__name__)

_CORE_PACKAGES = ("polars", "pyarrow", "datafusion", "pydantic", "orjson", "rustworkx")

_SLURM_VARS = (
    "SLURM_JOB_ID",
    "SLURM_NODELIST",
    "SLURM_NNODES",
    "SLURM_NTASKS",
    "SLURM_CLUSTER_NAME",
)


class SlurmInfo(BaseModel):
    job_id: str | None = None
    nodelist: str | None = None
    nnodes: str | None = None
    ntasks: str | None = None
    cluster_name: str | None = None


class DiagnosticsReport(BaseModel):
    hostname: str
    platform: str
    python_version: str
    python_path: str
    cwd: str
    user: str
    slurm: SlurmInfo = Field(default_factory=SlurmInfo)
    uv_path: str | None = None
    packages: dict[str, str] = Field(default_factory=dict)
    elapsed_seconds: float = 0.0


def _get_package_version(name: str) -> str:
    """Return the installed version of *name*, or 'NOT FOUND'."""
    try:
        return importlib.metadata.version(name)
    except importlib.metadata.PackageNotFoundError:
        return "NOT FOUND"


def collect_diagnostics(
    core_packages: Sequence[str] = _CORE_PACKAGES,
) -> DiagnosticsReport:
    """Collect environment diagnostics and return a structured report."""
    t0 = time.monotonic()

    slurm = SlurmInfo(
        job_id=os.environ.get("SLURM_JOB_ID"),
        nodelist=os.environ.get("SLURM_NODELIST"),
        nnodes=os.environ.get("SLURM_NNODES"),
        ntasks=os.environ.get("SLURM_NTASKS"),
        cluster_name=os.environ.get("SLURM_CLUSTER_NAME"),
    )

    packages = {pkg: _get_package_version(pkg) for pkg in core_packages}

    elapsed = time.monotonic() - t0

    return DiagnosticsReport(
        hostname=platform.node(),
        platform=platform.platform(),
        python_version=platform.python_version(),
        python_path=sys.executable,
        cwd=os.getcwd(),
        user=os.environ.get("USER", "unknown"),
        slurm=slurm,
        uv_path=shutil.which("uv"),
        packages=packages,
        elapsed_seconds=round(elapsed, 3),
    )


def log_diagnostics(
    core_packages: Sequence[str] = _CORE_PACKAGES,
) -> DiagnosticsReport:
    """Log environment information useful for verifying compute jobs."""
    report = collect_diagnostics(core_packages=core_packages)

    logger.info("--- environment diagnostics ---")
    logger.info("hostname: %s", report.hostname)
    logger.info("platform: %s", report.platform)
    logger.info("python: %s (%s)", report.python_version, report.python_path)
    logger.info("cwd: %s", report.cwd)
    logger.info("user: %s", report.user)

    # SLURM variables (only logged when present)
    slurm_active = False
    for var, field in zip(_SLURM_VARS, SlurmInfo.model_fields, strict=True):
        value = getattr(report.slurm, field)
        if value is not None:
            slurm_active = True
            logger.info("%s: %s", var, value)
    if not slurm_active:
        logger.info("SLURM: not running inside a job")

    # uv availability
    logger.info("uv: %s", report.uv_path or "not found on PATH")

    # Core dependency versions
    for pkg, ver in report.packages.items():
        logger.info("%s: %s", pkg, ver)

    logger.info("diagnostics completed in %.3f s", report.elapsed_seconds)
    logger.info("diagnostics_json: %s", orjson.dumps(report.model_dump()).decode())
    logger.info("--- end diagnostics ---")

    return report
