# Overview

This nixos configuration repository contains nixosSystem definitions for different hosts (2 Desktop, some servers) with system.nix entrypoint.
The host `watchtower` is a aarch64 machine, others x86-64.
Secret provisioning is done with [sops-nix](https://github.com/mic92/sops-nix).
Pins are defined and updated with [lon](https://github.com/nikstur/lon).

# Maintainance notes:

## attic

```bash
# Read Only Token
atticd-atticadm make-token --sub 'ro' --validity '1 year'  --pull '*'

# admin Token
atticd-atticadm make-token --sub 'admin' --validity '1 year' --push '*' --pull '*' --delete '*' --create-cache '*' --destroy-cache '*' --configure-cache '*' --configure-cache-retention '*'
```
