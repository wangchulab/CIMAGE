#!/bin/bash
#
# Sets up environment for, and passes variables to python script which adds
# preview script tag to cimage html files

err() {
  echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $@" >&2
}

if [[ -z "${1}" ]]; then
    err "Please provide files to operate on."
    exit "${E_DID_NOTHING}"
fi

readonly FILE="$(readlink -f ${0})"
readonly SCRIPT_PATH="$(dirname ${FILE})"

# activate python virtual env
source "${SCRIPT_PATH}/env/bin/activate"

# run python script passing all arguments
python "${SCRIPT_PATH}/modify-existing-dta.py" "$@"

# deactivate python virtual env
deactivate