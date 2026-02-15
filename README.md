# Antigravity VNC Launcher

Run Antigravity inside a Fluxbox desktop over VNC/noVNC with optional Xray VPN proxying.

## Quick Start

1. Create local VPN config from template:
   - `cp v2ray-client.json.example v2ray-client.json`
2. Fill in your server credentials in `v2ray-client.json`.
3. Start services:
   - `./start-with-vnc.sh`
4. Check status:
   - `./status-vnc.sh`
5. Stop everything:
   - `./stop-vnc.sh`

## Workstation URL And Routing Domain

- `config.env` auto-detects cloud workstation host when possible from:
  - `CLOUD_WORKSTATION_HOST`
  - `CLOUD_WORKSTATION_FQDN`
  - `CLOUD_WORKSTATION_HOSTNAME`
  - `CLOUD_WORKSTATION_URL`
  - `WORKSTATION_HOST`
  - `HOSTNAME` (if it ends with `.cloudworkstations.dev`)
- You can override directly:
  - `NOVNC_URL`
  - `WORKSTATION_DOMAIN`

`start-vpn.sh` replaces `YOUR_WORKSTATION_DOMAIN` in VPN config at runtime using `WORKSTATION_DOMAIN`.
When your workstation domain changes, update `WORKSTATION_DOMAIN` (or set `NOVNC_URL`) instead of editing scripts.

## Secrets Guidance

- Keep `v2ray-client.json` and `v2ray-client-reality.json` local/untracked.
- Prefer environment-injected secrets or a secrets manager for CI/shared environments.

## Development Shell

Use:
- `nix develop`

This provides the script dependencies in one shell; `nix-shell` shebangs remain for one-shot script execution compatibility.
