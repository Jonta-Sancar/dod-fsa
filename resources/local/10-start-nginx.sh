#!/bin/bash
set -euo pipefail

# Verifica a configuração antes de subir.
nginx -t

# Sobe em modo daemon; se falhar, o container cai.
nginx
