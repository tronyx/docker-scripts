#!/usr/bin/env bash
#
# Backup Docker app dirs, update images, and rebuild containers w/ Docker-Compose
# Tronyx
set -eo pipefail
IFS=$'\n\t'

# Define some vars
tempDir='/tmp/'
composeFile='/home/docker-compose.yml'
containerNamesFile="${tempDir}container_names.txt"
# Define appdata directory path (No trailing slash)
appdataDirectory='/home/'
# Define backup directory (No trailing slash)
backupDirectory='/mnt/docker_backup/'
today=$(date +%Y-%m-%d)
# Define time to keep backups
days=$(( ( $(date '+%s') - $(date -d '2 months ago' '+%s') ) / 86400 ))
# Define your domain (No scheme)
domain='domain.com'
# Define your SMS e-mail address (AT&T as an example)
smsAddress='5551235555@txt.att.net'

# Update Docker images
update_images() {
  /usr/local/bin/docker-compose -f "${composeFile}" pull -q
}

# Create list of container names
create_containers_list() {
  docker ps --format '{{.Names}}' |sort > "${containerNamesFile}"
}

# Take down containers and networks
compose_down() {
  /usr/local/bin/docker-compose -f "${composeFile}" down
}

# Loop through all containers to backup appdata dirs
backup() {
  while IFS= read -r CONTAINER; do
    tar czf "${backupDirectory}""${CONTAINER}"-"${today}".tar.gz "${appdataDirectory}""${CONTAINER}"/
  done < <(cat "${containerNamesFile}")
}

# Start containers and sleep to make sure they have time to startup
compose_up() {
  /usr/local/bin/docker-compose -f "${composeFile}" up -d --no-color
  sleep 120
}

# Unpause UptimeRobot monitors if domain status is 200, otherwise leave them paused and send an SMS
domain_check(){
  domainStatus=$(curl -sI https://"${domain}" |grep -i http/ |awk '{print $2}')
  domainCurl=$(curl -sI https://"${domain}" |head -2)
  if [ "${domainStatus}" == 200 ]; then
    :
  else
    echo "${domainCurl}" |mutt -s "${domain} is still down after weekly backup!" "${smsAddress}"
  fi
}

# Cleanup backups older than two months and perform docker prune
cleanup(){
  find "${backupDirectory}"*.tar.gz -mtime +"${days}" -type f -delete
  docker system prune -f -a --volumes
}

main(){
  update_images
  create_containers_list
  compose_down
  backup
  compose_up
  domain_check
  cleanup
}

main
