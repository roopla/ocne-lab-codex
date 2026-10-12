# Local development, builds and tests

These steps operate on the workstation only. They do not create database schemas or Kubernetes resources. The local demo always forces memory mode, binds 127.0.0.1 and removes DB_USER/DB_PASSWORD/DB_DSN from its child environments.

## 1. Requirements and locations

- Node.js 24, Python 3.10 or newer, JDK 21. Existing Windows host: Node 24.19.0 and Python 3.10.8.
- A portable Temurin 21.0.12.1+1 JDK was downloaded under `D:\OCNE19-Lab\private\app-tools` and checked against Adoptium's published SHA256.
- Python packages are installed under `D:\OCNE19-Lab\private\rac-app-venv`; Java jars under `backend/java-notes/lib` and classes under `backend/java-notes/build`, both ignored by Git.
- Four free localhost ports: 8080-8083 (demo) or 18080-18083 (automated API tests).
- Internet for initial dependencies. No Oracle client installation is needed.

Dependencies are pinned in the Python lock file and Java JSON lock. Python lock versions were resolved/tested on Windows/Python 3.10; Linux/Python 3.12 container builds are still an acceptance step. Container base images use readable version tags; after building, record/pin their observed digests before wider use. No claim of a vulnerability scan or immutable base-image lock is made.

## 2. Windows PowerShell

```powershell
Set-Location D:\OCNE19-Lab\apps\rac-lab-board
node --version
python --version
# Only if a JDK is not already available:
.\scripts\Install-Local-JDK.ps1
python scripts/prepare.py
if ($LASTEXITCODE -ne 0) { throw 'Local preparation failed' }
python scripts/dev.py
```

Open http://localhost:8080. A prominent LOCAL DEMO banner must appear. Create a task and a note. Each footer should name the local service and `DEMO (no RAC)`. Press Ctrl+C in the launcher terminal to stop its processes. Records disappear on restart; the demo is not a persistence or RAC test. If a port is busy, use `python scripts/dev.py --base-port 8090`, then http://localhost:8090.

`prepare.py` locates JDK via JAVA_HOME, PATH or this lab's private portable JDK. It verifies Java jar hashes, creates the Python virtual environment, installs the pinned requirements and compiles `NotesServer.java`. It never runs SQL, SSH or kubectl. Initial Java jar checksums were recorded from downloads via Maven Central HTTPS; subsequent builds verify the lock file.

## 3. Equivalent Bash

On a Linux development machine with Node 24, Python 3.10+ including `venv`, and JDK 21 installed:

```bash
cd /path/to/OCNE19-Lab/apps/rac-lab-board
node --version
python3 --version
javac -version
python3 scripts/prepare.py
python3 scripts/dev.py
```

Use the JDK's actual path if needed: `export JAVA_HOME=/your/jdk-21`. The scripts use that checkout's `private/` and `logs/` folders and choose POSIX virtual-environment paths automatically. In Windows Git Bash, the checkout is `/d/OCNE19-Lab`; use `python` if your Windows interpreter is not exposed as `python3`. Linux portability is implemented but has not been executed in this Windows-only validation.

## 4. Repeatable tests

From the app root, the following syntax is identical in PowerShell and Bash (substitute `python3` where needed):

```text
python tests/test_contract.py
python tests/test_oracle_transaction.py
node --check frontend/server.mjs
node --check frontend/public/app.js
node --check backend/node-gateway/server.mjs
```

The HTTP suite compiles Java and starts all four real processes on loopback ports 18080-18083, explicitly in memory mode. It checks both languages, concurrent writes, duplicate IDs, body limits, tracing, cross-origin handling and loss of a backend/gateway. Cleanup stops only the child PIDs it started, even after a failed test. The Python fake-driver suite tests bound parameters, commit, duplicate rollback and unknown commit handling; it does not prove Oracle driver compatibility or real RAC behavior.

Optional UI test, using the lab's existing Puppeteer/Edge tooling, in a second terminal while `scripts/dev.py` is running on 8080:

```powershell
node tests/browser.cjs
```

It checks create, simulated lost write response, preserved UUID after browser reload, deduplication, mobile layout and HTML escaping. It updates the local screenshot in `docs/diagrams/application-preview.png`. The optional test assumes Puppeteer under `private/diagram-tools`; set BROWSER_PATH to a Chromium executable if using another OS.

## 5. Build containers later

Docker CLI exists on this host, but its Linux engine was stopped. No Docker engine was started and no image was built during this task. Use a Linux-capable build machine or deliberately start the engine later when host memory allows.

PowerShell, after the engine is available:

```powershell
Set-Location D:\OCNE19-Lab\apps\rac-lab-board
python scripts/prepare.py
python scripts/build_images.py --archive D:\OCNE19-Lab\private\rac-app-images-1.0.0.tar
if ($LASTEXITCODE -ne 0) { throw 'Image build/export failed' }
```

Equivalent Bash:

```bash
cd /path/to/OCNE19-Lab/apps/rac-lab-board
python3 scripts/prepare.py
python3 scripts/build_images.py --archive ../../private/rac-app-images-1.0.0.tar
```

The helper builds linux/amd64 images named `localhost/rac-board-frontend:1.0.0`, `localhost/rac-board-gateway:1.0.0`, `localhost/rac-board-tasks:1.0.0` and `localhost/rac-board-notes:1.0.0`. It does not deploy, push or copy them to workers. It refuses to overwrite an existing archive. A changed `--tag` must also be reflected in the four Deployment image fields. `imagePullPolicy: Never` deliberately requires all images staged on both workers; missing images fail visibly instead of pulling an unrelated registry image.

For individual build commands and source orientation, see the README inside each frontend/backend folder. For future staging and deployment, continue to [DEPLOYMENT.md](DEPLOYMENT.md).

## Optional asset checker dependency

`tests/check_assets.py` additionally uses PyYAML (6.0.2 on this workstation). It is a development-only dependency, not an application/container dependency. On a fresh checkout, install it into the already-created private virtual environment:

PowerShell, from the app root:

```powershell
& ..\..\private\rac-app-venv\Scripts\python.exe -m pip install PyYAML==6.0.2
& ..\..\private\rac-app-venv\Scripts\python.exe tests/check_assets.py
```

Bash equivalent:

```bash
../../private/rac-app-venv/bin/python -m pip install PyYAML==6.0.2
../../private/rac-app-venv/bin/python tests/check_assets.py
```

The existing workstation already has this dependency; no global package change is required there.
