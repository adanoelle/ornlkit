"""Tests for the diagnostics module."""

import logging

from ornlkit.diagnostics import _get_package_version, log_diagnostics


def test_log_diagnostics_produces_output(caplog: logging.LogRecord) -> None:
    with caplog.at_level(logging.INFO):
        log_diagnostics()

    assert "environment diagnostics" in caplog.text
    assert "end diagnostics" in caplog.text
    assert "hostname:" in caplog.text
    assert "python:" in caplog.text
    assert "polars:" in caplog.text


def test_get_package_version_known() -> None:
    version = _get_package_version("polars")
    assert version != "NOT FOUND"
    # Version string should look like a version number
    assert "." in version


def test_get_package_version_unknown() -> None:
    assert _get_package_version("no-such-package-xyz-999") == "NOT FOUND"
