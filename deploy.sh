#!/usr/bin/env bash
# Trigger a build and deploy of the current web-writings master tip.
set -euo pipefail
gh workflow run deploy.yml --repo MathiasSM/website --ref master
