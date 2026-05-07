#!/usr/bin/env sh
set -eu

corepack enable
corepack pnpm install --frozen-lockfile
corepack pnpm validate:deploy
corepack pnpm deploy:prod
