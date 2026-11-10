# Install the required tools

This guide prepares a Windows machine to run the project with Ubuntu on WSL 2 and Docker. Then it installs Power BI Desktop for the report. A native x86-64 Linux host needs only steps 3–5 and 7.

Python, Java, Kafka, Flink, Trino, SeaweedFS and Oracle run in containers. You do not install them on the host.

| Tool | Tested version | Minimum | Purpose |
|---|---|---|---|
| Windows | 10/11 x64 | Build with WSL 2 support | Host for WSL and Power BI Desktop |
| WSL 2 + Ubuntu | Ubuntu 24.04 LTS, kernel 6.x | Ubuntu 22.04 | Linux shell that runs the scripts |
| Docker Engine | 29.9.3 | Engine with BuildKit | Builds and runs the containers |
| Docker Compose plugin | v5.7.0 | v2 CLI (`docker compose`) | Starts the project-scoped stack |
| Docker Buildx | 0.38.1 | Bundled with Docker | Builds the Flink and tools images |
| Git | 2.43 | Any recent 2.x | Clones the repository |
| Bash, `flock`, `timeout`, `od`, `diff`, `mktemp` | Ubuntu defaults | — | Used by the scripts in `scripts/` |
| Power BI Desktop | 2.143 (May 2025) | Build that supports PBIP, PBIR and TMDL | Opens the `.pbip` report |

## Hardware

- An x86-64 (amd64) CPU. The Oracle Database Free image in Compose is amd64-only, so ARM machines are not supported.
- 8 GB RAM on the host. Give WSL at least 4 GB (step 2). The staged scripts were verified with 3.7 GiB RAM and 1 GiB swap available to WSL.
- About 20 GB free disk space for images, build cache and demo volumes.
- Internet access for the first build. It downloads images from Docker Hub, `container-registry.oracle.com` and `ghcr.io`, Maven JARs and PyPI packages.

## 1. Install WSL 2 and Ubuntu (Windows)

Open **PowerShell as Administrator** and run:

```powershell
wsl --install -d Ubuntu-24.04
```

Restart Windows if prompted. Then open **Ubuntu 24.04** from the Start menu and create a Linux user name and password. Make sure the distribution uses WSL 2 and is up to date:

```powershell
wsl --update
wsl --list --verbose
```

The `VERSION` column must show `2`. If it shows `1`, run `wsl --set-version Ubuntu-24.04 2`.

## 2. Give WSL enough memory (Windows)

By default WSL can use half of the host RAM. To set the limit explicitly, create `%UserProfile%\.wslconfig` in Notepad:

```ini
[wsl2]
memory=6GB
swap=4GB
```

Use `memory=4GB` on an 8 GB host. Apply the change from PowerShell, then reopen Ubuntu:

```powershell
wsl --shutdown
```

## 3. Install Docker

Choose **one** option. Both expose the `docker` command inside Ubuntu.

### Option A: Docker Desktop (Windows)

1. Download and install [Docker Desktop for Windows](https://docs.docker.com/desktop/setup/install/windows-install/). Select **Use WSL 2 instead of Hyper-V** during setup.
2. Open **Settings → General** and keep **Use the WSL 2 based engine** enabled.
3. Open **Settings → Resources → WSL integration** and turn on **Ubuntu-24.04**. Select **Apply & restart**.
4. Keep Docker Desktop on **Linux containers**.

### Option B: Docker Engine inside Ubuntu

Run these commands in the Ubuntu terminal. They follow [Docker's official Ubuntu instructions](https://docs.docker.com/engine/install/ubuntu/).

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

Allow your user to run Docker without `sudo`, and make sure systemd starts the daemon:

```bash
sudo usermod -aG docker "$USER"
grep -q '^systemd=true' /etc/wsl.conf || printf '[boot]\nsystemd=true\n' | sudo tee -a /etc/wsl.conf
```

Run `wsl --shutdown` in PowerShell, reopen Ubuntu, and enable the service:

```bash
sudo systemctl enable --now docker
```

Do not install both options for the same distribution. If Docker Desktop is installed, use its WSL integration instead of Docker Engine.

## 4. Install Git and the shell utilities (Ubuntu)

Ubuntu includes most of these tools. This command installs any that are missing:

```bash
sudo apt-get update
sudo apt-get install -y git util-linux coreutils diffutils curl
```

`flock` comes from `util-linux`. `timeout`, `od` and `mktemp` come from `coreutils`, and `diff` comes from `diffutils`. `curl` is only needed for the Docker installation.

## 5. Check the installation (Ubuntu)

```bash
docker version --format 'Docker Engine {{.Server.Version}} ({{.Server.Os}}/{{.Server.Arch}})'
docker compose version
docker buildx version
git --version
flock --version
timeout --version | head -n 1
docker run --rm hello-world
```

The server must report `linux/amd64`, and `docker compose version` must print v2 or later. `hello-world` confirms that Docker can pull and run images without `sudo`. If you get `permission denied` on `/var/run/docker.sock`, reopen the terminal after `usermod`, or run `newgrp docker`.

## 6. Install Power BI Desktop (Windows)

1. Install Power BI Desktop from the [Microsoft Store](https://aka.ms/pbidesktopstore) or the [Microsoft Download Center](https://www.microsoft.com/en-us/download/details.aspx?id=58494). The Store version updates automatically. Use the 64-bit installer from the Download Center.
2. Open **File → Options and settings → Options → Preview features**. If your build still lists them, enable:
   - **Power BI Project (.pbip) save option**
   - **Store semantic model using TMDL format**
   - **Store reports using enhanced metadata format (PBIR)**
3. Restart Power BI Desktop.

Newer releases may enable PBIP, TMDL or PBIR by default and no longer list them as preview features.

Power BI Desktop runs only on Windows. On a Linux-only host, you can run the pipeline and use the CSV exports, but you cannot open the `.pbip`.

## 7. Get the project (Ubuntu)

Clone into the Linux filesystem, not under `/mnt/c`. Docker bind mounts and file permissions work reliably only on the Linux filesystem.

```bash
cd ~
git clone https://github.com/tannm28/entertainment_lakehouse.git
cd entertainment_lakehouse
scripts/init_env.sh
scripts/run_demo.sh
```

`init_env.sh` creates the private `.env` with random credentials. Do not commit it. The first `run_demo.sh` builds the images and pulls about 10 GB, so it can take 15–30 minutes. Continue with the [README](../README.md#run-the-demo-from-a-clean-checkout).

## 8. Connect Power BI to the running stack

- **Demo mode** needs no running containers.
- **Trino mode**: the Compose stack publishes Trino on `127.0.0.1:8080` inside WSL. WSL forwards `localhost` to Windows by default, so set `TrinoBaseUrl` to `http://127.0.0.1:8080`, or use the `TRINO_PORT` from `.env`. If Windows cannot connect, make sure `.wslconfig` does not set `localhostForwarding=false`.
- **CSV mode**: after `scripts/export_dashboard.sh`, set `CsvFolder` to the export folder through the WSL network path. For example, `\\wsl$\Ubuntu-24.04\home\<linux-user>\entertainment_lakehouse\.runtime\exports`.

See the [Power BI guide](../powerbi/README.md) for the refresh steps.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `docker: command not found` in Ubuntu | Docker Desktop: enable WSL integration for the distribution. Docker Engine: repeat step 3, option B. |
| `Cannot connect to the Docker daemon` | Start Docker Desktop, or run `sudo systemctl start docker`. |
| `no matching manifest for linux/arm64` when pulling Oracle | The host is ARM. Use an x86-64 machine. |
| Containers exit with code 137, or Oracle never becomes healthy | WSL is out of memory. Raise `memory` in `.wslconfig`, stop other stacks, and run one demo at a time. |
| Ports 8080 or 8081 are in use | Initialize a separate checkout with other ports: `scripts/init_env.sh my-project 18081 18080`. |
| `Run scripts/init_env.sh first.` | Run `scripts/init_env.sh` at the repository root. |
| Scripts fail with `$'\r': command not found` | The checkout was converted to Windows line endings. Clone again inside Ubuntu, not with Git for Windows. |
