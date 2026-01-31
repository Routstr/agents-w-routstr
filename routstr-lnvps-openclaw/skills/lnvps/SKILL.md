---
name: lnvps
description: Manage LNVPS virtual private servers using Nostr authentication
---

# LNVPS

## Purpose
Manage LNVPS virtual private servers using Nostr authentication.

## Full API
`https://api.lnvps.net/swagger/index.html`

## Commands

### Check VM Status & Expiry
```bash
./lnvps.sh status
```
Lists all your VMs with their expiry dates and status.

### Get Renewal Invoice
```bash
./lnvps.sh renew <vm_id>
```
Gets a Lightning invoice to renew a specific VM.

### List VMs
```bash
./lnvps.sh list
```
Simple list of VM IDs and names.

## Requirements

- `nak` - Nostr Army Knife (https://github.com/fiatjaf/nak)
- `jq` - JSON processor
- `curl` - HTTP client

## Configuration

Nostr keys are read from `~/.openclaw/identity/nostr.config.json` automatically.

## How It Works

Uses NIP-98 HTTP Auth to authenticate API requests with the configured Nostr keypair. The script signs events with kind 27235 containing the URL and method being accessed.

## API Reference

- Base URL: `https://api.lnvps.net/api/v1`
- Auth: NIP-98 (Nostr event in Authorization header)
