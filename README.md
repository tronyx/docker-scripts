# Docker Scripts

Various Bash scripts to work with Docker containers.

## Backup/Update Scripts

### Usage

![Script Usage](/Images/usage.png)

I utilize the CloudFlare maintenance page setup from [gilbN](https://github.com/gilbN) that is outlined [HERE](https://technicalramblings.com/blog/how-to-setup-a-cloudflare-worker-to-show-a-maintenance-page-when-ca-backup-plugin-is-running/). If you do not use this you will want to comment out the following lines of the script:

```
148    echo 'Enabling CloudFlare maintenance page...'
149    /root/scripts/start_maint.sh

237    stop_maint
```

### Backup Docker Compose Containers

Script to update, backup, or update and backup your Docker-Compose containers.

### Backup Docker Compose Containers w/ Application Healthchecks, Tronitor, & Docker Container Healthchecks Integration

Designed to be used with my [HealthChecks - Linux](https://github.com/tronyx/HealthChecks-Linux) and the below outlined Docker Container Healthchecks scripts. If you're not using one, you will want to comment out the corresponding lines in the script or make some other modifications so that no errors occur when the script is ran.

Script to update, backup, or update and backup your Docker-Compose containers that includes integration with my [Tronitor](https://github.com/christronyxyocum/tronitor) script that allows you to pause and unpause your HealthChecks.io, UptimeRobot, or StatusCake monitors manually or via a cronjob for scheduled maintenance, etc.

You will want to comment out/remove the lines for any monitoring provider that you do not use.

## Docker Container Healthchecks

Script to check that your Docker containers are running and, if not, send a message to Discord/Slack. Designed to be ran as a cronjob on the Linux Host that your Docker containers are running on.

## Example Cronjobs

### Update/Backup Script

Here is the cronjob that I use to run the update/backup script every Sunday morning at 5am:

```bash
## Backup and update Docker Compose containers every Sunday morning
0 5 * * 0 /home/tronyx/scripts/backup_docker_compose_containers.sh -a > /var/log/backup.log
```

The `> /var/log/backup.log` at the end allows me to log the output of the script so I can check it if there was an issue while it ran overnight.

### Docker Container Healthchecks Script

Here's the cronjob that I use to run the script every five minutes:

```bash
## Run Docker container healthcheck script
*/5 * * * * /home/tronyx/scripts/docker_container_healthchecks.sh
```