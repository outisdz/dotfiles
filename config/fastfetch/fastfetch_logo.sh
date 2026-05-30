#!/usr/bin/env bash
files=(./logo/*); echo "${files[RANDOM % ${#files[@]}]}"
