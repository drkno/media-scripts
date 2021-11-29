# Media Scripts

Scripts for starting a fully automated media server.

## Initial Setup

This assumes a systemd+docker OS, with a user and group 1000,1000.

1. Make a copy of `.env.example` to `.env` and edit variables within. Some tokens may need to be placeholders for initial setup
2. Find and replace `mydomain.com` and `myotherdomain.com` with your hostnames.
3. `ln -s /etc/systemd/system/pms.service ./pms.service`
4. `systemctl daemon-reload && systemctl enable pms`
5. `mkdir -p ./config/mount && docker run -it --rm -v ./config/mount:/config drkno/cloudmount:latest rclone_setup`
6. Update settings within other config files.
7. `systemctl start pms`

## Updating

```sh
# Update only non-critical services
./deploy.sh

# Redeploy all critical services
./deploy.sh all
```
