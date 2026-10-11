#!/bin/bash
set -euo pipefail
case $(hostname -s) in ocne-w1|ocne-w2) ;; *) exit 1;; esac
mountpoint -q /scratch
cd /scratch/software/stage/19c/19.32
sha256sum -c <<'HASHES'
ba8329c757133da313ed3b6d7f86c5ac42cd9970a28bf2e6233f3235233aa8d8  LINUX.X64_193000_db_home.zip
d668002664d9399cf61eb03c0d1e3687121fc890b1ddd50b35dcbe13c5307d2e  LINUX.X64_193000_grid_home.zip
5eba8519ac16e7eb2701f977b5f81f0e7f49225da1f430966bdc8fed9e649198  p39467003_190000_Linux-x86-64.zip
9cef81dc1de61635ec8680480b49db2334c35322f106189c1eb32f62cadc4350  p39472050_190000_Linux-x86-64.zip
ad67904c8c148ca1fcde5d0bb6f572a381e662c7d22735cffc5916ad2e330b2b  p6880880_190000_Linux-x86-64.zip
HASHES
