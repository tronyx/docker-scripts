#!/usr/bin/env bash
#
# Script to check container status and report to Discord if any of them are not running
# Tronyx

# Define some variables
tempDir='/tmp/'
containerNamesFile="${tempDir}container_names.txt"
# Exclude containers you do not want to be checked
exclude=("container-1" "container-2" "container-3")
# Your webhook URL for the Discord channel you want alerts sent to
discordWebhookURL=''
# Your Discord numeric user ID
# To find your user ID just type \@<username> or \@<role>, like so \@username#1337
# It will look something like <@123492578063015834> and you NEED the exclamation point like below
discordUserID='<@!123492578063015834>'

# Function to create list of Docker containers
create_containers_list() {
    docker ps -a --format '{{.Names}}' | sort > "${containerNamesFile}"
}

# Function to check Docker containers
check_containers() {
    if [ -f ${containerNamesFile} ]; then
        if [ -s ${containerNamesFile} ]; then
        while IFS= read -r container; do
            if [[ ! ${exclude[*]} =~ ${container} ]]; then
                containerStatus=$(docker inspect "${container}" | jq .[].State.Status | tr -d '"')
                if [ "${containerStatus}" = 'running' ];then
                    :
                elif [ "${containerStatus}" = 'exited' ];then
                    curl -s -H "Content-Type: application/json" -X POST -d '{"content": "'"${discordUserID}"' The '"${container}"' container is currently stopped!"}' "${discordWebhookURL}"
                elif [ "${containerStatus}" = 'dead' ];then
                    curl -s -H "Content-Type: application/json" -X POST -d '{"content": "'"${discordUserID}"' The '"${container}"' container is currently dead!"}' "${discordWebhookURL}"
                elif [ "${containerStatus}" = 'restarting' ];then
                    curl -s -H "Content-Type: application/json" -X POST -d '{"content": "'"${discordUserID}"' The '"${container}"' container is currently restarting!"}' "${discordWebhookURL}"
                else
                    curl -s -H "Content-Type: application/json" -X POST -d '{"content": "'"${discordUserID}"' The '"${container}"' container currently has an unknown status!"}' "${discordWebhookURL}"
                fi
            fi
        done < <(cat "${containerNamesFile}")
    else
        echo "There are currently no Docker containers on this Server!"
        exit 0
    fi
    else
        echo "Unable to find ${containerNamesFile}!"
        exit 1
    fi
}

# Main function to run all other functions
main() {
    create_containers_list
    check_containers
}

main
