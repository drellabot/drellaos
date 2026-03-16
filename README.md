# drellaos

Fedora [bootc](https://containers.github.io/bootc/) image for a server running Drella.

## Image

```
ghcr.io/drellabot/drellaos:latest
```

## How to modify

**Add a package** — add it to the `dnf install` list in `Containerfile`.

**Add an SSH user** — add their GitHub username to the `users` list in `Containerfile`. Their public keys are fetched at build time.

## CI

The image is built daily, on every push to `main`, and on pull requests. See [`.github/workflows/build.yml`](.github/workflows/build.yml) for details. Images are pushed to GHCR on `main` builds only.
