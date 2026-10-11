#!/bin/bash
# Request fresh samples from the already configured Chrony sources after host resume.
# Reference: https://chrony-project.org/doc/4.8/chronyc.html (burst and waitsync).
set -euo pipefail
case $(hostname -s) in ocne-op|ocne-cp|ocne-w1|ocne-w2) ;; *) exit 1;; esac
[[ $(id -u) == 0 ]]
hostname
chronyc tracking
chronyc selectdata
chronyc burst 4/4
chronyc waitsync 12 0.1 0 5
chronyc tracking
chronyc selectdata
