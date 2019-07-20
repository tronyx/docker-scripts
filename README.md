# Docker Scripts

Various Bash scripts to work with Docker containers.

## Backup/Update Scripts

### Usage

![Script Usage](/Images/usage.png)

### Backup Docker Compose Containers

Script to update, backup, or update and backup your Docker-Compose containers.

### Backup Docker Compose Containers w/ Tronitor Integration

Script to update, backup, or update and backup your Docker-Compose containers that includes integration with my [Tronitor](https://github.com/christronyxyocum/tronitor) script that allows you to pause and unpause your HealthChecks.io, UptimeRobot, or StatusCake monitors manually or via a cronjob for scheduled maintenance, etc.

## Docker Container Healthchecks

Script to check that your Docker containers are running and, if not, send a message to Discord/Slack. Designed to be ran as a cronjob on the Linux Host that your Docker containers are running on.

### Example Cronjob

Here's the cronjob that I use to run the script every five minutes:

```bash
## Run Docker container healthcheck script
*/5 * * * * /root/scripts/docker_container_healthchecks.sh
```