log() {
    local message="$1"
    local timestamp=$(date +%Y-%m-%d-%H-%M-%S)
    echo "${timestamp} - ${functionality}: ${message}"
}
