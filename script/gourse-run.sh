#!/usr/bin/env bash

# Define directories
GIT_DIR=~/git
SCRIPT_DIR=~/github/git-visualise/script
OUTPUT_VIDEO="${SCRIPT_DIR}/git-video.mp4"
LOG_DIR=$(mktemp -d "./tempdir.XXXXXX") # Temporary directory for logs
COMBINED_LOG="${LOG_DIR}/combined.txt"
GIT_UPDATE=false  # Default: do not update Git repositories
FILTER_REGEX=".*" # Default: process all repositories

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --git-update)
            GIT_UPDATE=true
            shift
            ;;
        --filter)
            FILTER_REGEX="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Clean up function
cleanup() {
    rm -rf "$LOG_DIR"
}
# trap cleanup EXIT


# Ensure Gource and FFmpeg are installed
command -v gource >/dev/null 2>&1 || { echo "Gource not found. Install it first."; exit 1; }
command -v ffmpeg >/dev/null 2>&1 || { echo "FFmpeg not found. Install it first."; exit 1; }

# Generate logs for each repo
echo "Processing repositories..."
rm -f "$COMBINED_LOG"

for REPO in "$GIT_DIR"/*/.git; do
    [ -d "$REPO" ] || continue
    REPO_PATH=$(dirname "$REPO")
    REPO_NAME=$(basename "$REPO_PATH")

    # Apply regex filter
    if ! [[ "$REPO_NAME" =~ $FILTER_REGEX ]]; then
        # echo "Skipping $REPO_NAME (does not match filter)"
        continue
    fi

    if [ "$GIT_UPDATE" = true ]; then
        echo "Updating $REPO_NAME..."
        git -C "$REPO_PATH" pull --rebase --autostash
    fi

    LOG_FILE="${LOG_DIR}/${REPO_NAME}.txt"
    
    echo "Generating log for $REPO_NAME..."
    gource --output-custom-log "$LOG_FILE" "$REPO_PATH"

    # Adjust paths in log file to include repo name
    # sed -i -r "s#(.+)\|#\1|/$REPO_NAME#" "$LOG_FILE"
    # MacOS sed requires an empty string after -i
    sed -i '' -E "s#(.+)\|#\1|/$REPO_NAME#" "$LOG_FILE"

    # Append to combined log
    cat "$LOG_FILE" >> "$COMBINED_LOG"
done

# Sort combined log
sort -n "$COMBINED_LOG" -o "$COMBINED_LOG"

# Generate video from the logs
echo "Creating visualization..."
gource --auto-skip-seconds 0.1 -s 0.1 --hide-root --output-ppm-stream - \
        -1920x1080 --start-date '2024-01-01 01:01:01' "$COMBINED_LOG" \
| ffmpeg -y -i - -c:v libx264 -crf 23 -profile:v baseline -level 3.0 \
         -pix_fmt yuv420p -c:a aac -ac 2 -b:a 128k -movflags faststart \
         "$OUTPUT_VIDEO"

echo "Video saved to $OUTPUT_VIDEO"


exit 0
# gource --output-custom-log log1.txt repo1
# # use a 'sed' regular expression to add an extra parent directory to the path of the files in each project:
# sed -i -r "s#(.+)\|#\1|/repo1#" log1.txt

# # combine the logs of the projects:
# cat log1.txt log2.txt | sort -n > combined.txt

# # --hide-root option to not connect the top level directories to make them look more distinct
# gource --auto-skip-seconds 0.1 -s 0.1 --output-ppm-stream combined.txt \
# | ffmpeg    -i - -c:v libx264 -crf 23 -profile:v baseline -level 3.0 \
#             -pix_fmt yuv420p -c:a aac -ac 2 -b:a 128k -movflags faststart \
#             git-video.mp4

