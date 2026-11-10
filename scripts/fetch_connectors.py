"""Download and verify the pinned Flink connector JARs from Maven Central."""
import hashlib
from pathlib import Path
import sys
from tempfile import NamedTemporaryFile
from urllib.request import urlopen

MAVEN = "https://repo.maven.apache.org/maven2/"


def sha256(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def fetch(manifest, destination):
    destination.mkdir(parents=True, exist_ok=True)
    for line in manifest.read_text().splitlines():
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        expected, source = line.split()
        target = destination / Path(source).name
        if target.exists() and sha256(target) == expected:
            print(f"Verified {target.name}")
            continue
        with NamedTemporaryFile(dir=destination, delete=False) as pending:
            path = Path(pending.name)
            try:
                with urlopen(MAVEN + source, timeout=60) as response:
                    for chunk in iter(lambda: response.read(1024 * 1024), b""):
                        pending.write(chunk)
                pending.close()
                if sha256(path) != expected:
                    raise RuntimeError(f"SHA-256 mismatch for {target.name}")
                path.replace(target)
            finally:
                path.unlink(missing_ok=True)
        print(f"Downloaded and verified {target.name}")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit("Usage: fetch_connectors.py MANIFEST DESTINATION")
    fetch(Path(sys.argv[1]), Path(sys.argv[2]))
