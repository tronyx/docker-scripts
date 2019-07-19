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
# Define appdata directory path (Requires trailing slash)
appdataDirectory='/home/'
# Define backup directory (Requires trailing slash)
backupDirectory='/mnt/docker_backup/'
today=$(date +%Y-%m-%d)
# Define time to keep backups
days=$(( ( $(date '+%s') - $(date -d '2 months ago' '+%s') ) / 86400 ))
# Define your domain (No scheme)
domain='domain.com'
# Define your SMS e-mail address (AT&T as an example)
smsAddress='5551235555@txt.att.net'
# Arguments
readonly args=("$@")
# Colors
readonly grn='\e[32m'
readonly red='\e[31m'
readonly ylw='\e[33m'
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
readonly scriptpath="$(cd -P "$(dirname "${scriptname}")" > /dev/null && pwd)"

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
    root_check
    cmdline "${args[@]:-}"
    check_empty_arg
    if [ "${backup}" = 'true' ]; then
        create_containers_list
        compose_down
        backup
        compose_up
        domain_check
        cleanup
    elif [ "${update}" = 'true' ]; then
        update_images
        create_containers_list
        compose_down
        compose_up
        domain_check
        cleanup
    elif [ "${all}" = 'true' ]; then
        update_images
        create_containers_list
        compose_down
        backup
        compose_up
        domain_check
        cleanup
    fi
}

main