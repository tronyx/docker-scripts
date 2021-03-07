#!/usr/bin/env bash
#
# Backup Docker app dirs, update images, and rebuild containers w/ Docker-Compose
# Tronyx
set -eo pipefail
IFS=$'\n\t'

# Define some vars
tempDir='/tmp/tronitor/'
composeFile='/home/docker-compose.yml'
containerNamesFile="${tempDir}container_names.txt"
appdataDirectory='/home/'
backupDirectory='/mnt/docker_backup/'
today=$(date +%Y-%m-%d)
days=$(( ( $(date '+%s') - $(date -d '2 months ago' '+%s') ) / 86400 ))
domain='domain.com'
# Set your notification type
discord='false'
text='false'
# Set to true if you want a notification at the start of the maintenance
notifyStart='false'
# Set your Discord webhook URL if you set discord to true
webhookURL=''
# Define your SMS e-mail address (AT&T as an example) if you set text to true
smsAddress='5551234567@txt.att.net'
# Exclude containers, IE:
# ("plex" "sonarr" "radarr" "lidarr")
exclude=("sonarr")
# Arguments
readonly args=("$@")
# Colors
readonly grn='\e[32m'
readonly red='\e[31m'
readonly lorg='\e[38;5;130m'
readonly endColor='\e[0m'

# Define usage and script options
usage() {
    cat <<- EOF

    Usage: $(echo -e "${lorg}$0${endColor}") $(echo -e "${grn}"-[OPTION]"${endColor}")

    $(echo -e "${grn}"-b/--backup"${endColor}""${endColor}")      Backup all Docker containers.
    $(echo -e "${grn}"-u/--update"${endColor}")      Update all Docker containers.
    $(echo -e "${grn}"-a/--all"${endColor}")         Backup and update all Docker containers.
    $(echo -e "${grn}"-h/--help"${endColor}")        Display this usage dialog.

EOF

}

# Define script options
cmdline() {
    local arg=
    local local_args
    local OPTERR=0
    for arg; do
        local delim=""
        case "${arg}" in
            # Translate --gnu-long-options to -g (short options)
            --backup) local_args="${local_args}-b " ;;
            --update) local_args="${local_args}-u " ;;
            --all) local_args="${local_args}-a " ;;
            --help) local_args="${local_args}-h " ;;
            # Pass through anything else
            *)
                [[ ${arg:0:1} == "-" ]] || delim='"'
                local_args="${local_args:-}${delim}${arg}${delim} "
                ;;
        esac
    done

    # Reset the positional parameters to the short options
    eval set -- "${local_args:-}"

    while getopts "hbua" OPTION; do
        case "$OPTION" in
            b)
                backup=true
                ;;
            u)
                update=true
                ;;
            a)
                all=true
                ;;
            h)
                usage
                exit
                ;;
            *)
                echo -e "${red}You are specifying a non-existent option!${endColor}"
                usage
                exit
                ;;
        esac
    done
    return 0
}

# Script Information
get_scriptname() {
    local source
    local dir
    source="${BASH_SOURCE[0]}"
    while [[ -L ${source} ]]; do
        dir="$(cd -P "$(dirname "${source}")" > /dev/null && pwd)"
        source="$(readlink "${source}")"
        [[ ${source} != /* ]] && source="${dir}/${source}"
    done
    echo "${source}"
}

readonly scriptname="$(get_scriptname)"

# Check whether or not user is root or used sudo
root_check() {
    if [[ ${EUID} -ne 0 ]]; then
        echo -e "${red}You didn't run the script as root!${endColor}"
        echo -e "${red}Doing it for you now...${endColor}"
        echo ''
        sudo bash "${scriptname:-}" "${args[@]:-}"
        exit
    fi
}

# Check for empty arg
check_empty_arg() {
    for arg in "${args[@]:-}"; do
        if [ -z "${arg}" ]; then
            usage
            exit
        fi
    done
}

# Function to check that the webhook URL is defined if discord is set to true.
check_webhook_url() {
    if [[ -z ${webhookURL} ]] && [[ ${discord} == 'true' ]]; then
        echo -e "${red}You didn't define your Discord webhook URL, exiting!${endColor}"
        exit 1
    fi
}

# Function to enable CloudFlare maintenance page and notify of maintenance
# start, if notifyStart set to true
# Adjust or comment out the path to the CF maintenance page script
start_maint() {
    if [[ ${notifyStart} == 'true' ]]; then
        if [[ ${discord} == 'true' ]]; then
            curl -s -H "Content-Type: application/json" -X POST -d '{"embeds": [{"title": "Docker Compose Backup/Update Started!", "description": "The scheduled run of the Docker Compose containers update/backup script has started.", "color": 39219}]}' "${webhookURL}"
        fi
    fi
    echo 'Enabling CloudFlare maintenance page...'
    /root/scripts/start_maint.sh
}

# Update Docker images
update_images() {
    echo 'Updating Docker images...'
    COMPOSE_HTTP_TIMEOUT=900 COMPOSE_PARALLEL_LIMIT=25 /usr/local/bin/docker-compose -f "${composeFile}" pull -q --ignore-pull-failures >/dev/null 2>&1 || echo "There was an issues pulling the image for one or more container. Run a pull manually to determine which containers are problematic."
}

# Create list of container names
create_containers_list() {
    echo 'Creating list of Docker containers...'
    /usr/local/bin/docker-compose -f "${composeFile}" config --services | sort > "${containerNamesFile}"
}

# Stop containers
compose_down() {
    echo 'Performing docker-compose down...'
    COMPOSE_HTTP_TIMEOUT=900 COMPOSE_PARALLEL_LIMIT=25 /usr/local/bin/docker-compose -f "${composeFile}" down
}

# Loop through all containers to backup appdata dirs
backup() {
    while IFS= read -r CONTAINER; do
        if [[ ! ${exclude[*]} =~ ${CONTAINER} ]]; then
            echo "Backing up ${CONTAINER}..."
            tar czf "${backupDirectory}""${CONTAINER}"-"${today}".tar.gz -C "${appdataDirectory}" "${CONTAINER}"/
        fi
    done < <(cat "${containerNamesFile}")
}

# Start containers and sleep to make sure they have time to startup
compose_up() {
    echo 'Performing docker-compose up...'
    COMPOSE_HTTP_TIMEOUT=900 COMPOSE_PARALLEL_LIMIT=25 /usr/local/bin/docker-compose -f "${composeFile}" up -d --no-color
    echo 'Sleeping for 5 minutes to allow the containers to start...'
    sleep 300
}

# Function to disable CloudFlare maintenance page
# Adjust or comment out the path to the CF maintenance page script
stop_maint() {
    echo 'Disabling CloudFlare maintenance page...'
    /root/scripts/stop_maint.sh
}

# Unpause monitors if TronFlix status is 200
unpause_check(){
    echo 'Sleeping for 5 minutes to allow the applications to finish starting...'
    sleep 300
    echo 'Performing monitor unpause check...'
    domainStatus=$(curl -sI https://"${domain}" | grep -i http/ |awk '{print $2}')
    domainCurl=$(curl -sI https://"${domain}" | head -2)
    if [ "${domainStatus}" == 200 ]; then
        echo 'Success!'
        stop_maint
        if [[ ${discord} == 'true' ]]; then
            curl -s -H "Content-Type: application/json" -X POST -d '{"embeds": [{"title": "Docker Compose Backup/Update Completed!", "description": "The scheduled run of the Docker Compose containers backup/update was successful. The specified Domain responded with an HTTP status of 200 after the containers were brought back online.", "color": 39219}]}' "${webhookURL}"
        fi
    else
        if [[ ${text} == 'true' ]]; then
            echo "${domainCurl}" |mutt -s "${domain} is still down after weekly backup!" "${smsAddress}"
        elif [[ ${discord} == 'true' ]]; then
            curl -s -H "Content-Type: application/json" -X POST -d '{"embeds": [{"title": "Docker Compose Backup/Update Failed!", "description": "The scheduled run of the Docker Compose containers backup/update has failed! The specified Domain did NOT respond with an HTTP status of 200 after the containers were brought back online!", "color": 16711680}]}' "${webhookURL}"
        fi
    fi
}

# Cleanup backups older than two months and perform docker prune
cleanup(){
    echo 'Removing old backups and performing docker prune...'
    find "${backupDirectory}"*.tar.gz -mtime +"${days}" -type f -delete
    docker system prune -f -a --volumes
}

main(){
    root_check
    cmdline "${args[@]:-}"
    check_empty_arg
    check_webhook_url
    if [ "${backup}" = 'true' ]; then
        start_maint
        create_lock_files
        create_containers_list
        compose_down
        backup
        backup_env_files
        compose_up
        unpause_check
        cleanup
    elif [ "${update}" = 'true' ]; then
        start_maint
        create_lock_files
        update_images
        create_containers_list
        compose_up
        unpause_check
        cleanup
    elif [ "${all}" = 'true' ]; then
        start_maint
        create_lock_files
        update_images
        create_containers_list
        compose_down
        backup
        backup_env_files
        compose_up
        unpause_check
        cleanup
    fi
}

main