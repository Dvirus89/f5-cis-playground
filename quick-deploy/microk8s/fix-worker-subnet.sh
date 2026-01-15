#!/usr/bin/env bash
set -euo pipefail
CNI_YAML="/var/snap/microk8s/current/args/cni-network/cni.yaml"
command -v microk8s >/dev/null 2>&1 || { echo "microk8s not found in PATH" >&2; exit 1; }
[[ -f "$CNI_YAML" ]] || { echo "Missing $CNI_YAML" >&2; exit 1; }
SELECTED_IP=""
while read -r ip; do
  if [[ "$ip" =~ ^10\.1\.[0-9]+\.[0-9]+$ ]] && [[ ! "$ip" =~ ^10\.1\.1\.[0-9]+$ ]]; then SELECTED_IP="$ip"; break; fi
done < <(ip -o -4 addr show up | awk '{print $4}' | cut -d/ -f1)
[[ -n "$SELECTED_IP" ]] || { echo "No eligible IP found in 10.1.0.0/16 excluding 10.1.1.0/24" >&2; exit 1; }
python3 - "$CNI_YAML" "$SELECTED_IP" <<'PY'
import re,sys
path,ip=sys.argv[1],sys.argv[2]
lines=open(path,"r",encoding="utf-8").readlines()
out=[]; pending=False; changed=False
for line in lines:
    if re.match(r"\s*- name:\s*IP_AUTODETECTION_METHOD\s*$",line): pending=True; out.append(line); continue
    if pending and re.match(r"\s*value:\s*\".*\"\s*$",line):
        indent=re.match(r"^(\s*)",line).group(1); out.append(f'{indent}value: "can-reach={ip}"\n'); pending=False; changed=True; continue
    out.append(line)
if not changed: sys.stderr.write("Did not find IP_AUTODETECTION_METHOD value to update.\n"); sys.exit(1)
open(path,"w",encoding="utf-8").writelines(out)
PY
microk8s kubectl apply -f "$CNI_YAML"
NODE_NAME="${NODE_NAME:-}"
[[ -n "$NODE_NAME" ]] || NODE_NAME="$(microk8s kubectl get nodes -o jsonpath='{.items[?(@.metadata.name=="'"$(hostname)"'")].metadata.name}')"
[[ -n "$NODE_NAME" ]] || NODE_NAME="$(microk8s kubectl get nodes -o jsonpath='{.items[?(@.metadata.name=="'"$(hostname -s)"'")].metadata.name}')"
if [[ -n "$NODE_NAME" ]]; then microk8s kubectl -n kube-system delete pod -l k8s-app=calico-node --field-selector spec.nodeName="$NODE_NAME"; else echo "Warning: could not determine node name. Set NODE_NAME to delete the local calico-node pod." >&2; fi
echo "Calico IP autodetection set to can-reach=${SELECTED_IP}"
