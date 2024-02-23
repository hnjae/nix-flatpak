#!/usr/bin/env -S just --justfile
alias fmt := format

format:
  alejandra .
