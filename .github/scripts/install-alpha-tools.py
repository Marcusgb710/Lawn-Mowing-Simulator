"""Install the project's pinned Linux tools using verified HTTPS downloads."""

import io
from pathlib import Path
import tomllib
import urllib.request
import zipfile
import os


tools = tomllib.loads(Path("rokit.toml").read_text())["tools"]
destination = Path(os.environ["RUNNER_TEMP"]) / "alpha-tools"
destination.mkdir(exist_ok=True)
for name in ("rojo", "selene", "stylua"):
    repository, version = tools[name].rsplit("@", 1)
    tag = version if name == "selene" else f"v{version}"
    archive = {
        "rojo": f"rojo-{version}-linux-x86_64.zip",
        "selene": f"selene-{version}-linux.zip",
        "stylua": "stylua-linux-x86_64.zip",
    }[name]
    url = f"https://github.com/{repository}/releases/download/{tag}/{archive}"
    with urllib.request.urlopen(url, timeout=60) as response:
        with zipfile.ZipFile(io.BytesIO(response.read())) as package:
            executable = destination / name
            executable.write_bytes(package.read(name))
            executable.chmod(0o755)
with open(os.environ["GITHUB_PATH"], "a") as path_file:
    path_file.write(f"{destination}\n")
