#!/usr/bin/env bash
# Launch an application finder...
# Just run this script.

# =========
# Functions
# =========

# Strip commands from codes that we don't need.
stripper() {

    str=$1
    str=${str//\%f/}
    str=${str//\%F/}
    str=${str//\%u/}
    str=${str//\%U/}
    str=${str//\%d/}
    str=${str//\%D/}
    str=${str//\%n/}
    str=${str//\%N/}
    str=${str//\%i/}
    str=${str//\%c/}
    str=${str//\%k/}
    str=${str//\%v/}
    str=${str//\%m/}
    echo $str

}

# =========
# Variables
# =========

list=/tmp/fzf-jump.txt
touch "${list}"
hist=/tmp/fzf-jump-hist.txt

prefix=':'
suffix=' '
    
# ====
# Init
# ====

# Load all modules.
while read line ; do
    setsid --fork $SHELL -c "${line} >> ${list}"
done <<< $( find "$(dirname $0)/modules" -name "*.sh" )

# ===============
# FZF and execute
# ===============

# Pick something with fzf.
selection=$( cat ${list} \
    | cut -f1 -d';' \
    | fzf --history=${hist} \
          --cycle \
          --bind "change:reload(cat ${list} | cut -f1 -d';')" \
          --border=sharp \
          --header="Syntaxis: \"${prefix}[rm]${suffix}<arg>\"" \
          --header-first \
          --layout="reverse"
)
selection=$( echo -n "${selection}" )

# Check if a non-matching argument was given. 
if [[ -z "${selection}" ]] ; then 
    
    # No new write -> no command (exited without asking anything).
    ((elapsedSeconds = $(date +%s) - $(date +%s -r "${hist}") ))
    if [[ ${elapsedSeconds} -gt 2 ]] ; then 
        rm ${list}
        exit
    fi

    action=$( tail -n 1 "${hist}" )

    # Move to new workspace.
    if [[ "${action}" =~ ^${prefix}[mM]${suffix} ]] ; then
        name=$( sed "s/^${prefix}[mM]${suffix}//" <<< "${action}" )
        swaymsg focus tiling
        swaymsg move window to workspace "${name}"
        swaymsg workspace "${name}"
    
    # Rename workspace
    elif [[ "${action}" =~ ^${prefix}[rR]${suffix} ]] ; then 
        name=$( sed "s/^${prefix}[rR]${suffix}//" <<< "${action}")
        swaymsg rename workspace to "${name}"
        ~/.scripts/notify.sh -t 1000 "${name}" "Switched workspaces"
    
    # Execute the given command.
    elif [[ "${action}" =~ ^${prefix}${suffix} ]] ; then 
        action=${action#"${prefix}${suffix}"}
        setsid --fork $SHELL -c "alacritty -e ${action}"
    fi
fi

ex=$(stripper "$(grep "^${selection};.*$" "${list}" | cut --complement -f1 -d';')")

# Execute the command.
setsid --fork $SHELL -c "${ex}" &> /dev/null

rm ${list}
