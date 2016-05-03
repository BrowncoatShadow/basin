#!/usr/bin/env bash
# basin.sh - collect all the streams you care about in one place
# by BrowncoatShadow and Crendgrim
# <https://github.com/BrowncoatShadow/basin.sh>

# TODO Re-implement debug functionality
# TODO Re-implement command line arguments for passing custom lists

### Helper Functions
get_system() { # determine os type and take action accordingly
  local system_type
  system_type="$(uname)"
  if [[ "${system_type}" == "Darwin" ]]; then # OS X
    # add jq's install dir (via homebrew) to PATH.
    PATH=${PATH}:/usr/local/bin
    # helper for interactive mode, returns the given time using system's `date`
    system_date() { echo "$(date -jf %s "${1}" "+%H:%M"))"; }
  elif [[ "${system_type}" == "Linux" ]] # Linux
    system_date() { echo "$(date --date="@${1}" "+%H:%M"))"; }
  else # unknown system
    error "${system_type} is not supported."
    exit 1
  fi
}
error() { # print a colorful message to STDERR
  local red='\033[0;31m'
  local nc='\033[0m'
  echo -e "${red}[ERROR] ${1}${nc}" >&2
}
depends_on() { # check for a given dependency, exit if missing
  command -v ${1} > /dev/null
  if [[ "$?" == "1" ]]; then
    error "Missing dependency: ${1}"
    exit 1
  fi
}
generate_config() { # setup function for generating basinrc
  # if the file exists already, ask the user if he really wants to replace it
  if [[ -f "${HOME}/.config/basinrc" ]]; then
    local prompt_string="The configuration file \`${HOME}/.config/basinrc\` exists already. Are you sure you want to replace it? [y/N] "
    read -p "${prompt_string}"
    # TODO replace this with extended regular expression
    if [[ ${REPLY} != "y" && ${REPLY} != "Y" && ${REPLY} != "yes" && ${REPLY} != "YES" ]]; then
      return 0
    fi
  fi
  # Generate default basinrc.
  cat > ${HOME}/.config/basinrc <<"CONFIG"
#!/bin/bash
# basinrc - Configuration file for basin.sh. by BrowncoatShadow and Crendgrim
# <https://github.com/BrowncoatShadow/basin.sh>


### GENERAL SETTINGS
# DBFILE - The database file for storing currently online streams.
#	default: DBFILE=${HOME}/.local/share/basin/online.json
# DEBUGFILE - The file for storing debug data. This can help to debug the script itself.
#	NOTE: This functionality is currently broken.
#	default: DEBUGFILE=${HOME}/.local/share/basin/debug.json
# MODULE - The notification module to use.
#	default: MODULE=echo_notify
DBFILE=${HOME}/.local/share/basin/online.json
DEBUGFILE=${HOME}/.local/share/basin/debug.json
MODULE=echo_notify


### SERVICE SETTINGS
# Settings for the various streaming services to check.

### TWITCH SETTINGS
# TWITCH_USER - Your Twitch user in all lower-case letters. If set, use this user's followed channels.
#	default: TWITCH_USER=
# TWITCH_FOLLOWLIST - Additional list of streams to check on, divided by spaces.
#	default: TWITCH_FOLLOWLIST=""
# TWITCH_CLIENT_ID - Twitch client_id, generate at <http://www.twitch.tv/kraken/oauth2/clients/new>.
#	default: TWITCH_CLIENT_ID=
TWITCH_USER=
TWITCH_FOLLOWLIST=""
TWITCH_CLIENT_ID=

### HITBOX SETTINGS
# HITBOX_USER - Your Hitbox user in all lower-case letters. If set, use this user's followed channels.
#	default: HITBOX_USER=
# HITBOX_FOLLOWLIST - Additional list of streams to check on, divided by spaces.
#	default: HITBOX_FOLLOWLIST=""
HITBOX_USER=
HITBOX_FOLLOWLIST=""

### AZUBU SETTINGS
# AZUBU_FOLLOWLIST - List of streams to check on, divided by spaces.
# default: AZUBU_FOLLOWLIST=""
AZUBU_FOLLOWLIST=""

### NOTIFIER SETTINGS
# Settings for the user-visable notifications for changes to a stream status.

### PUSHBULLET SETTINGS
# Note: If PB_URLTARGET and PB_URITARGET are unset, the module will send to all targets.
#
# PB_TOKEN - Pushbullet access token. Find at <https://www.pushbullet.com/account>
#	default: PB_TOKEN=
# PB_URLTARGET - Space seperated list of pushbullet device_idens to send the URL to.
#	default: PB_URLTARGET=""
# PB_URITARGET - Space seperated list of pushbullet device_idens to send the URI to.
#	default: PB_URLTARGET=""
# PB_ALLURI - Change to 'true' to use application URI instead of URL when sending to all targets.
#	default: PB_URI=false
PB_TOKEN=
PB_URLTARGET=""
PB_URITARGET=""
PB_ALLURI=false

### OS X SETTINGS
# OSX_TERMNOTY - Set to 'true' to use terminal-notifier app instead of applescript. This enables clicking the notification to launch URL.
#	default: OSX_TERMNOTY=false
OSX_TERMNOTY=false
CONFIG
  # TODO Is this best practice?
  # open the new basinrc with the users ${EDITOR}, so they can configure it
  ${EDITOR} ${HOME}/.config/basinrc
}
setup_cron() { # setup function for creating cronjob
  # check if our cronjob exists already skip this step if it does
  # TODO this can be much cleaner
  local croncheck
  croncheck=$(crontab -l 2> /dev/null | grep -q 'basin.sh'  && echo 'exists')
  if [[ "${croncheck}" == "exists" ]]; then
    return
  fi

  local prompt_string="Would you like basin.sh to add itself to your crontab? (This runs the script every minute.) [y/N] "
  read -p "${prompt_string}"
  # TODO replace this with extended regular expression
  if [[ ${REPLY} != "y" && ${REPLY} != "Y" && ${REPLY} != "yes" && ${REPLY} != "YES" ]]; then
    return
  fi

  local source_dir
  source_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
  # FIXME Parse error being sent to mail by cron. Presumed to be caused by
  # characters in channel status returned by service APIs.
  # `parse error: Invalid numeric literal at line 1, column 20`
  # list crontab, concat that output with basin's cron job, feed back to crontab
  crontab -l 2> /dev/null \
    | { cat; echo "*/1 * * * * ${source_dir}/basin.sh"; } \
    | crontab -
}
load_config() { # load configuration from file
  # check if alternative config file is defined
  if [[ -n "${ALT_CONFIG}" ]]; then
    # if the config file does not exist yet, exit with a descriptive error message
    if [[ ! -f "${ALT_CONFIG}" ]]; then
      error "The specified configuration file ${ALT_CONFIG} is missing."
      error "You can create it by copying the default configuration file at \`${HOME}/.config/basinrc\`."
      error "If that file does not exist, you can create it by calling \`basin.sh -C\`."
      exit 1
    fi

    # use alt config file if defined
    CFGFILE=${ALT_CONFIG}
  else
    # if the config file does not exist yet, exit with a descriptive error message
    if [[ ! -f "${HOME}/.config/basinrc" ]]; then
      error "The default configuration file ${HOME}/.config/basinrc is missing."
      error "You can create it by calling \`basin.sh -C\`."
      exit 1
    fi

    # use default config file
    CFGFILE=${HOME}/.config/basinrc
  fi

  # load config file
  source ${CFGFILE}
}
check_file() { # generate given folders and files if they do not exist
  if [[ ! -f ${1} ]]; then
    mkdir -p $(dirname ${1})
    touch ${1}
  fi
  if [[ -z $(cat ${1}) ]]; then
    echo ${2} > ${1}
  fi
}
get_data() { # get data from json object
  echo "${1}" | jq -r '.[] | select(.name=="'${2}'") | .'${3}
}
get_db() { # get data from the database
  cat ${DBFILE} | jq -r '(.'${1}' // [])[] | select(.name=="'${2}'") | .'${3}
}
check_notify() { # check old and new online list and notify accordingly
  local service="${1}"
  local new_online_json="${2}"
  local channel="${3}"

  # check if stream is active
  local name
  name=$(get_data "${new_online_json}" "${channel}" 'name')
  if [[ "${name}" == "${channel}" ]]; then
    # check if it has been active since last check
    if [[ -n "${DBFILE}" ]]; then
      dbcheck=$(get_db ${service} ${name} 'name')
    fi

    local notify=true

    # grab important info from json check
    local sdisplay_name sgame slink sstatus
    sdisplay_name="$(get_data "${new_online_json}" "${channel}" 'display_name')"
    sgame="$(get_data "${new_online_json}" "${channel}" 'game')"
    slink="$(get_data "${new_online_json}" "${channel}" 'url')"
    sstatus="$(get_data "${new_online_json}" "${channel}" 'status')"

    # sometimes, the api sends broken results handle these gracefully
    if [[ "${sgame}" == null && "${sstatus}" == null ]]; then
      # if the stream was live before, assume the results to be broken, so we
      # don't re-notify
      if [[ -n "${dbcheck}" ]]; then
        # Recover the old data.
        sdisplay_name="$(get_db ${service} ${name} 'display_name')"
        sgame="$(get_db ${service} ${name} 'game')"
        sstatus="$(get_db ${service} ${name} 'status')"
        slink="$(get_db ${service} ${name} 'url')"
        # Output the broken stream.
        # This output can be used by the service plugins to replace the broken
        # record, so it does not show up in the database.
        echo null | jq '
          {"name":"'${name}'",
          "display_name":"'${sdisplay_name}'",
          "game":"'"${sgame}"'",
          "status":'"$(echo "${sstatus}" | jq -R '.')"',
          "url": "'"${slink}"'"}'
      fi
      # otherwise ignore the broken result to not get a null/null notification
      return -1
    fi

    # already streaming last time, check for updates
    if [[ -n "${dbcheck}" ]]; then
      notify=false
      local dbgame dbstatus
      dbgame="$(get_db ${service} ${name} 'game')"
      dbstatus="$(get_db ${service} ${name} 'status')"
      # notify when game or status change
      if [[ "${dbgame}" != "${sgame}" || "${dbstatus}" != "${sstatus}" ]]; then
        notify=true
      fi
    fi
    if [[ ${notify} == true ]]; then
      # send notification by using the module and giving it the arguments
      ${MODULE} "${sdisplay_name}" "${sgame}" "${sstatus}" "${slink}" "${service}"
    fi
  fi
}

### Notifiers
# These are the functions that are called whenever a stream changes its status
# to execute the user-visible notification.
# Each notifier gets the following parameters:
#   ${1}: The display name of the stream; the user-facing channel name.
#   ${2}: The game that is currently being played. Can be empty.
#   ${3}: The channel's status text, a descriptive caption set by the broadcaster.
#   ${4}: The link to the channel, correctly formatted for the service.
#   ${5}: The service the livestream is on.
echo_notify() { # notify by printing to STDOUT in the terminal
  echo "${5} | ${1} [${2}]: ${3} <${4}>"
}
kdialog_notify() { # notify by KDialog popup
  kdialog \
    --title "${1} is now live on ${5}" \
    --icon "video-player" \
    --passivepopup "<b>${2}</b><br>${3}"
}
osx_notify() { # notify with OS X native notifications
  # check which notification type to use
  if [[ "${OSX_TERMNOTY}" == "true" ]]; then
    # send using terminal-notifier
    terminal-notifier \
      -message "${3}" \
      -title "${5}" \
      -subtitle "${1} is now streaming ${2}" \
      -open "${4}"
  else
    # send using OS X applescript (no url support)
    osascript \
      -e "display notification \"${3}\" \
      with title \"${5}\" \
      subtitle \"${1} is now streaming ${2}\""
  fi
}
pb_notify() { # notify by PushBullet API notification
  # make sure we have a token
  if [[ -z "${PB_TOKEN}" ]]; then
    error "You need to set PB_TOKEN in your settings file."
    exit 1
  fi

  # TODO handle URI for services other than twitch
  # place the arguments from script into variables that the functions can use
  local name game stat url uri
  name="${1}"; game="${2}"; stat="${3}"; url="${4}"; uri="twitch://stream/${1}"

  # create functions for sending pushes
  allpush() {
    curl -s \
      --header 'Authorization: Bearer '${PB_TOKEN}'' \
      -X POST https://api.pushbullet.com/v2/pushes \
      --header 'Content-Type: application/json' \
      --data-binary '{"type": "link", "title": "'"${name}"'", "body": "'"[${game}] \\n${stat}"'", "url": "'"${1}"'"}' \
      > /dev/null
  }

  targetpush() {
    curl -s \
      --header 'Authorization: Bearer '${PB_TOKEN}'' \
      -X POST https://api.pushbullet.com/v2/pushes \
      --header 'Content-Type: application/json' \
      --data-binary '{"device_iden": "'"${1}"'", "type": "link", "title": "'"${name}"'", "body": "'"[${game}] \\n${stat}"'", "url": "'"${2}"'"}' \
      > /dev/null
  }

  # if no targets are defined, send to all targets
  if [[ -z "${PB_URLTARGET}" && -z "${PB_URITARGET}" ]]; then
    # if PB_URI is true, send the uri link instead of url
    local link
    if [[ "${PB_ALLURI}" == "true" ]]; then
      link="${uri}"
    else
      link="${url}"
    fi

    # push to all
    allpush ${link}
  fi

  # for each target in url list, send a push
  if [[ -n "${PB_URLTARGET}" ]]; then
    for target in ${PB_URLTARGET}; do
      targetpush ${target} ${url}
    done
  fi

  # for each target in uri list, send a push
  if [[ -n "${PB_URITARGET}" ]]; then
    for target in ${PB_URITARGET}; do
      targetpush ${target} ${uri}
    done
  fi
}

### Services
# The plugins for the different streaming services. These functions are
# responsible for fetching data from the foreign APIs, parsing this data and
# calling check_notify() for any live streams. That function will then decide
# whether to send a notification. Also, these plugins will output all current
# live channels as JSON, which then gets accumulated and saved into the database
# file.
get_channels_twitch() { # https://www.twitch.tv/
  # use the specified followlist, if set
  local twitch_list="${TWITCH_FOLLOWLIST}"

  # if user is set, fetch user's follow list and add them to the list
  if [[ -n ${TWITCH_USER} ]]; then 
    twitch_list="${twitch_list} \
      "$(curl -s \
      --header 'Client-ID: '${TWITCH_CLIENT_ID} \
      -H 'Accept: application/vnd.twitchtv.v3+json' \
      -X GET "https://api.twitch.tv/kraken/users/${TWITCH_USER}/follows/channels?limit=100" \
      | jq -r '.follows[] | .channel.name' \
      | tr '\n' ' ')
  fi

  # remove duplicates from the list
  twitch_list=$(echo $(printf '%s\n' ${twitch_list} | sort -u))

  # sanitize the list for the fetch url
  local url_list
  url_list=$(echo ${twitch_list} | sed 's/ /\,/g')

  # fetch the json for all followed channels
  local returned_data
  returned_data="$(curl -s \
    --header 'Client-ID: '${CLIENT} \
    -H 'Accept: application/vnd.twitchtv.v3+json' \
    -X GET "https://api.twitch.tv/kraken/streams?channel=${url_list}&limit=100")"

  # create new database
  local new_online_json
  new_online_json="$(echo "${returned_data}" | jq '
    [.streams[] |
    {name:.channel.name,
    display_name:.channel.display_name,
    game:.channel.game,
    status:.channel.status,
    url:.channel.url}]')"

  # notify for new streams
  for channel in ${twitch_list}; do
    local output
    output=$(check_notify 'twitch' "${new_online_json}" ${channel})
    # if we get a broken result, replace the old one
    if [[ $? != 0 ]]; then
      # remove entry
      new_online_json="$(echo "${new_online_json}" \
        | jq 'del(.[] | select(.name=="'${channel}'"))')"
      # re-insert recovered entry
      new_online_json="$(echo "${new_online_json}" | jq '. + ['"${output}"']')"
    fi
  done
  echo "${new_online_json}"
}
get_channels_hitbox() { # http://www.hitbox.tv/
  # use the specified followlist, if set
  local hitbox_list="${HITBOX_FOLLOWLIST}"
  # if user is set, fetch user's follow list and add them to the list
  if [[ -n ${HITBOX_USER} ]]; then
    && hitbox_list="${hitbox_list} \
    "$(curl -s \
    -X GET "https://api.hitbox.tv/following/user/?user_name=${HITBOX_USER}" \
    | jq -r '.following[] | .user_name' \
    | tr '\n' ' ')
  fi

  # remove duplicates from the list
  hitbox_list=$(echo $(printf '%s\n' ${hitbox_list} | sort -u))

  # fetch the json for all followed channels
  local new_online_json='[]'
  for channel in ${hitbox_list}; do
    local returned_data
    returned_data="$(curl -s -X GET "https://api.hitbox.tv/media/live/${channel}")"

    # sometimes the hitbox api returns garbage if that happens, handle it gracefully
    local is_live
    is_live="$(echo "${returned_data}" \
      | jq -r '.livestream[] | .media_is_live' \
      2>/dev/null)"

    if [[ $? == 4 ]]; then
      # insert entry recovered from database
      local sdisplay_name
      sdisplay_name="$(get_db 'hitbox' ${channel} 'display_name')"

      # did it even exist in the database?
      if [[ -n "${sdisplay_name}" ]]; then
        local sgame sstatus slink
        sgame="$(get_db 'hitbox' ${channel} 'game')"
        sstatus="$(get_db 'hitbox' ${channel} 'status')"
        slink="$(get_db 'hitbox' ${channel} 'url')"
        new_online_json="$(echo '\
          [{"name":"'${name}'", \
          "display_name":"'${sdisplay_name}'", \
          "game":"'"${sgame}"'", \
          "status":'"$(echo "${sstatus}" | jq -R '.')"', \
          "url": "'"${slink}"'"}]' \
          | jq "${new_online_json}"' + .')"
      fi

    elif [[ "${is_live}" == "1" ]]; then
      # insert into new database
      new_online_json="$(echo "${returned_data}" \
        | jq "${new_online_json}"'
        + [{name:.livestream[] | .media_name,
        display_name:.livestream[] | .media_display_name,
        game:.livestream[] | .category_name,
        status:.livestream[] | .media_status,
        url:.livestream[] | .channel.channel_link}]')"
    fi
  done

  # notify for new streams
  for channel in ${hitbox_list}; do
    check_notify 'hitbox' "${new_online_json}" ${channel,,}
  done
  echo "${new_online_json}"
}
get_channels_azubu() { http://www.azubu.tv/
  # remove duplicates from the list
  local azubu_list
  azubu_list=$(echo $(printf '%s\n' ${AZUBU_FOLLOWLIST} | sort -u))
  # sanitize the list for the fetch url
  local url_list
  url_list=$(echo ${azubu_list} | sed 's/ /\,/g')
  # fetch the json for all followed channels
  local returned_data
  returned_data="$(curl -s \
    -X GET "http://api.azubu.tv/public/channel/list?channels=${url_list}")"

  # create new database
  local new_online_json
  new_online_json="$(echo "${returned_data}" \
    | jq '
    [.data [] | select(.is_live == true) |
    {name: .user.username,
    display_name: .user.display_name,
    game: .category.title,
    status: .title,
    url: .url_channel}]')"

  # notify for new streams
  for channel in ${azubu_list}; do
    check_notify 'azubu' "${new_online_json}" ${channel}
  done
  echo "${new_online_json}"
}

### Interactive Menu
# This displays an interactive menu in the terminal that shows who the local
# database says are currently online. This interactive mode does not actively
# check for online streams, it simply shows the current state of the database in
# a friendly way. A regular instance of the script needs to be run in a cron job
# or similar to update the database. Thanks a lot to:
# <https://stackoverflow.com/questions/27945567/bash-script-overwrite-output-without-filling-scrollback/27946484#27946484>.
interactive_cleanup() { # exit interactive mode gracefully
  # revert black magic, exit the screen and recover old cursor position
  stty sane
  # exit the screen and recover old cursor position at this point, all changes
  # done by our script should be reverted
  tput rmcup
  # end the script here, don't query the API at all
  exit 0
}
interactive_output() { # generate the output for the interactive menu
  tput clear

  local last_checked
  last_checked=$(cat ${DBFILE} | jq -r '.lastcheck // 0')
  if [[ ${last_checked} -eq 0 ]]; then
    echo "Database too old, updating..."
    main
    last_checked=$(cat ${DBFILE} | jq -r '.lastcheck')
  fi

  # print the header
  echo -n "Streams currently live: (last checked at "
  system_date "${last_checked}"
  echo "[press q to exit]"

  # pretty-print the database json
  echo -e "$(cat ${DBFILE} | jq -r '
    (.twitch + .hitbox + .azubu)[] |
      [
        "\n\\033[1;34m", .display_name, "\\033[0m",
        (
          # Properly align the game for shorter channel names
          .display_name | length |
          if . < 8 then
            "\t\t"
          else
            "\t"
          end
        ),
        "\\033[0;36m", .game, "\\033[0m",
        "\n\\033[0;32m", .url, "\\033[0m",
        "\n", .status
      ] |
    add')"
  echo
}
interactive_menu() { # creates interactive menu and handles input
  # enables deletion of output, and sets the read timeout so we have immediate
  # reactions
  stty -icanon time 0 min 0
  # saves current position of the cursor, and opens new screen
  tput smcup
  # let's start by displaying our data
  interactive_output

  # We have to constantly run the loop to give a fast reaction should the user
  # want to quit, but we do not want to constantly update the output. Let's keep
  # track of how many iterations there were and only update every 25 * 0.4 = 10
  # seconds.
  local i=0

  local keypress=''
  # run the loop until [q] is pressed
  while [[ "${keypress}" != "q" ]]; do
    # we need some kind of timeout so we don't waste cpu time
    sleep 0.4
    # make sure to only update every ten seconds
    ((i+=1))
    if [[ ${i} -eq 25 ]]; then
      # output our stuff
      interactive_output
      i=0
    fi
    # If a button is pressed, read it. Since we set the minimum read length to 0
    # using stty, we do not wait for an input here but also accept empty input
    # (i.e. no keys pressed).
    read keypress

    # handle ctrl-c (SIGINT) gracefully and restore the proper prompt
    trap interactive_cleanup SIGINT
  done

  # reset and exit
  interactive_cleanup
}

### Main Function
main() {
  # check for dependencies
  depends_on jq
  depends_on curl

  # check for options
  while getopts ":c:Ci" opt; do
    case ${opt} in
      c) # use config passed as an argument
        ALT_CONFIG="${OPTARG}"
        ;;
      C) # generate the config and setup the cronjob, exit after
        generate_config
        setup_cron
        exit 0
        ;;
      i) # start interactive mode
        local interactive=true
        ;;
      \?) # unknown option
        error "Invalid option: -${OPTARG}"
        exit 1
        ;;
    esac
  done

  # bootstrap
  get_system
  load_config
  check_file ${DBFILE} "{}"
  if [[ "${debug}" == "true" ]]; then
    check_file ${DEBUGFILE} "[]"
  fi

  # TODO this should probably be broken apart and put in it's own function
  # cleanup: if the database file is older than 2 hours, consider it outdated
  # and remove its contents
  [[ -s ${DBFILE} && $(($(date +%s)-$(cat ${DBFILE} | jq -r '.lastcheck // 0'))) -gt 7200 ]] && echo "{}" > ${DBFILE}

  # check if we are supposed to be running in interactive mode
  if [[ "${interactive}" == "true" ]]; then
    interactive_menu
  else # non-interactive, act normal
    # TODO this should probably be broken out into a repeatable function
    # call the service plugins for the configured lists, which in turn call the
    # notification function, and saves their output to the database if wanted
    local new_online_db='{}'
    # check if we have a user set or any channels to follow
    local module_json
    if [[ -n "${TWITCH_USER}" || -n "${TWITCH_FOLLOWLIST}" ]]; then
      module_json="$(get_channels_twitch)"
      if [[ -z "${module_json}" ]]; then
        module_json="[[]]"
      fi
      new_online_db="$(echo "${module_json}" \
        | jq "${new_online_db} + {twitch: .}")"
    fi
    if [[ -n "${HITBOX_USER}" || -n "${HITBOX_FOLLOWLIST}" ]]; then
      module_json="$(get_channels_hitbox)"
      if [[ -z "${module_json}" ]]; then
        module_json="[[]]"
      fi
      new_online_db="$(echo "${module_json}" \
        | jq "${new_online_db} + {hitbox: .}")"
    fi
    if [[ -n "${AZUBU_FOLLOWLIST}" ]]; then
      module_json="$(get_channels_azubu)"
      if [[ -z "${module_json}" ]]; then
        module_json="[[]]"
      fi
      new_online_db="$(echo "${module_json}" \
        | jq "${new_online_db} + {azubu: .}")"
    fi

    # Save online database
    if [[ -n "${DBFILE}" ]]; then
      echo "${new_online_db}" \
        | jq '. + {lastcheck:'$(date +%s)'}' > ${DBFILE}
    fi
  fi
}
main "$@"
