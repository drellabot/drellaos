# drellaos

Fedora [bootc](https://containers.github.io/bootc/) image for a server running Drella.

## Image

```
ghcr.io/drellabot/drellaos:latest
```

## How to modify

**Add a package** — add it to the `dnf install` list in `Containerfile`.

**Add an SSH user** — add their GitHub username to the `users` list in `Containerfile`. Their public keys are fetched at build time.

## Local Deployment

### Building a VM Disk Image

To run drellaos locally, convert the bootc image to a virtual machine disk using [bootc-image-builder](https://github.com/osbuild/bootc-image-builder).

**1. Build or pull the drellaos image**

```bash
# Option A: Build locally
podman build -t localhost/drellaos:latest .

# Option B: Use the published image
podman pull ghcr.io/drellabot/drellaos:latest
```

**2. Create a customization config**

Copy `config.json.example` to `config.json` and customize:
- Replace the SSH public key with your own (`cat ~/.ssh/id_rsa.pub`)
- Adjust filesystem sizes if needed
- Optionally add additional users

```bash
cp config.json.example config.json
# Edit config.json with your SSH key
```

**3. Convert to qcow2 disk image**

The bootc-image-builder container must have access to the image in its storage. If you built the image as a non-root user but plan to run bootc-image-builder as root (typical), you'll need to transfer the image:

```bash
# Transfer image to root's podman storage
podman save localhost/drellaos:latest -o /tmp/drellaos.tar
sudo podman load -i /tmp/drellaos.tar
rm /tmp/drellaos.tar
```

Run bootc-image-builder:

```bash
# On RHEL-based systems, use the RHEL registry
sudo podman run --rm -it --privileged --pull=newer \
  --security-opt label=type:unconfined_t \
  -v $(pwd)/config.json:/config.json:ro \
  -v $(pwd)/output:/output \
  -v /var/lib/containers/storage:/var/lib/containers/storage \
  registry.redhat.io/rhel10/bootc-image-builder:latest \
  --type qcow2 --config /config.json localhost/drellaos:latest

# On other systems, use the upstream image
sudo podman run --rm -it --privileged --pull=newer \
  --security-opt label=type:unconfined_t \
  -v $(pwd)/config.json:/config.json:ro \
  -v $(pwd)/output:/output \
  -v /var/lib/containers/storage:/var/lib/containers/storage \
  quay.io/centos-bootc/bootc-image-builder:latest \
  --type qcow2 --config /config.json localhost/drellaos:latest
```

The resulting disk image will be at `output/qcow2/disk.qcow2`.

**Note:** There's a known issue where filesystem customizations in TOML format may not work correctly. Use JSON format (as shown in the example) to avoid this.

### Importing the VM

The `disk.qcow2` file can be imported into various virtualization platforms:

**libvirt/KVM:**
```bash
virt-install --name drellaos \
  --memory 4096 --vcpus 2 \
  --disk path=/path/to/disk.qcow2,format=qcow2 \
  --import --os-variant fedora-unknown \
  --network network:default
```

**Other platforms:**
- **Proxmox**: Upload qcow2 via web UI or `qm importdisk`
- **VirtualBox**: Convert to VDI with `qemu-img convert -f qcow2 -O vdi disk.qcow2 disk.vdi`
- **VMware**: Convert to VMDK with `qemu-img convert -f qcow2 -O vmdk disk.qcow2 disk.vmdk`
- **Cloud providers**: Most support qcow2 or raw images for custom VM imports

### Environment-Specific Behavior

The drellaos image is designed to work in both cloud (AWS) and local environments:

- **In AWS**: The `drella-fetch-secrets` systemd service fetches credentials from AWS Secrets Manager on boot
- **In local deployments**: The service detects it's not running in AWS and gracefully skips, allowing you to configure credentials manually

For local orchestrator usage, you'll typically configure:
- Anthropic API key in `~/.anthropic/api_key`
- GitHub CLI authentication via `gh auth login`

## CI

The image is built daily, on every push to `main`, and on pull requests. See [`.github/workflows/build.yml`](.github/workflows/build.yml) for details. Images are pushed to GHCR on `main` builds only.
