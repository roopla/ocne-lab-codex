"""Offline consistency checks; Kubernetes schema validation is a separate kubeconform command."""

import ast, json, re, sys
from pathlib import Path
from urllib.parse import unquote, urlsplit
import yaml

APP = Path(__file__).resolve().parents[1]
links = 0
for file in APP.rglob("*.md"):
    for target in re.findall(
        r"!?\[[^\]]*\]\(([^)]+)\)", file.read_text(encoding="utf-8")
    ):
        if "://" in target or target.startswith("#"):
            continue
        path = unquote(urlsplit(target).path)
        assert (file.parent / path).exists(), f"Broken link: {file}: {target}"
        links += 1
for file in (
    list((APP / "scripts").glob("*.py"))
    + list((APP / "tests").glob("*.py"))
    + [APP / "backend/python-tasks/server.py"]
):
    ast.parse(file.read_text(encoding="utf-8"), filename=str(file))
objects = []
for name in ["00-namespace.yaml", "10-config.yaml", "20-workloads.yaml"]:
    objects.extend(yaml.safe_load_all((APP / "kubernetes" / name).read_text()))
assert len(objects) == 14
assert not any(
    o["kind"] in ("Secret", "PersistentVolume", "PersistentVolumeClaim", "RacDatabase")
    for o in objects
)
bykind = {
    kind: [o for o in objects if o["kind"] == kind]
    for kind in ["Deployment", "Service", "PodDisruptionBudget", "ConfigMap"]
}
for deployment in bykind["Deployment"]:
    spec = deployment["spec"]
    assert spec["replicas"] == 2
    template = spec["template"]
    pod = template["spec"]
    c = pod["containers"][0]
    assert (
        pod["nodeSelector"] == {"raccluster": "raccluster01"}
        and pod["automountServiceAccountToken"] is False
    )
    assert (
        c["imagePullPolicy"] == "Never"
        and c["securityContext"]["readOnlyRootFilesystem"] is True
    )
    assert (
        c["livenessProbe"]["httpGet"]["path"] == "/livez"
        and c["readinessProbe"]["httpGet"]["path"] == "/readyz"
    )
    assert c["image"].startswith("localhost/rac-board-")
    service = next(
        s
        for s in bykind["Service"]
        if s["metadata"]["name"] == deployment["metadata"]["name"]
    )
    assert service["spec"]["selector"] == spec["selector"]["matchLabels"]
    assert service["spec"]["ports"][0]["port"] == c["ports"][0]["containerPort"]
    assert all(
        template["metadata"]["labels"][k] == v
        for k, v in service["spec"]["selector"].items()
    )
    if c["name"] in ("tasks", "notes"):
        refs = {e["name"]: e["valueFrom"] for e in c["env"] if "valueFrom" in e}
        assert (
            refs["DB_PASSWORD"]["secretKeyRef"]["name"] == "board-" + c["name"] + "-db"
        )
        assert refs["STORE_MODE"]["configMapKeyRef"]["key"] == "STORE_MODE"
config = bykind["ConfigMap"][0]["data"]
assert config["STORE_MODE"] == "oracle"
assert config["DB_DSN"].count("(HOST=") == 2
for binary in APP.rglob("*.jar"):
    assert "lib" in binary.parts
print(
    f"PASS: {links} local documentation links, Python syntax, 14 manifest resources and service/secret/port/security references"
)
