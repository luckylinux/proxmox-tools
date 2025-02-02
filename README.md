# proxmox-tools
Various Tools for Proxmox VE Systems


# Troubleshooting
## Guest Debugging
```
while [[ 1 -ne 0 ]]; do timestamp=$(date +"%Y%m%d-%Hh%Mm%Ss"); writes=$(cat /sys/block/sdb/stat | awk '{print $7*512/1024/1024/1024}'); echo "${timestamp}: ${writes}GB"; sleep 0.5; done
```