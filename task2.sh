#!/bin/bash

set -o pipefail
set -e

convert_to_json() {
    local input_file=$1
    local output_file="output.json"

    if [[ ! -f "$input_file" ]]; then
        printf "Error: Input file '%s' not found.\n" "$input_file" >&2
        return 1
    fi

    # Debug: Pokaż zawartość pliku wejściowego
    printf "DEBUG: Input file content:\n"
    cat "$input_file"
    printf "\n"

    local test_name
    test_name=$(grep -oP '(?<=\[ ).*(?= \])' "$input_file")
    if [[ -z "$test_name" ]]; then
        printf "Error: Unable to extract test name.\n" >&2
        return 1
    fi
    printf "DEBUG: Extracted test name: %s\n" "$test_name"

    local tests_json
    tests_json=$(grep -P '^(ok|not ok)' "$input_file" | \
        awk '
        BEGIN { print "[" }
        {
            status = ($1 == "ok") ? "true" : "false"
            name = ""
            for (i = 3; i <= NF - 2; i++) name = name " " $i
            name = name " " $(NF - 1)  # Add the second last field for the full name
            sub(/^[0-9]+\s+/, "", name)
            gsub(/,\s*$/, "", name)       # Remove trailing commas after name
            gsub(/^ /, "", name)          # Trim leading spaces
            printf "{\"name\":\"%s\",\"status\":%s,\"duration\":\"%s\"},\n", name, status, $NF
        }
        END { print "]" }
        ' | sed ':a;N;$!ba;s/,\n]/\n]/')

    if [[ -z "$tests_json" ]]; then
        printf "Error: Unable to extract test details.\n" >&2
        return 1
    fi
    # Debug: Pokaż wygenerowane JSON dla testów
    printf "DEBUG: Generated tests JSON:\n%s\n\n" "$tests_json"

    local summary_line
    summary_line=$(grep -oP '\d+ \(.+?tests passed, .+?tests failed.+?$' "$input_file")
    if [[ -z "$summary_line" ]]; then
        printf "Error: Unable to extract summary.\n" >&2
        return 1
    fi
    printf "DEBUG: Extracted summary line: %s\n" "$summary_line"

    local success failed rating duration
    success=$(echo "$summary_line" | grep -oP '^\d+(?= \(of)')
    failed=$(echo "$summary_line" | grep -oP '(?<=, )\d+(?= tests failed)')
    rating=$(echo "$summary_line" | grep -oP '\d+(\.\d+)?(?=%)')
    duration=$(echo "$summary_line" | grep -oP '(?<=spent )\d+ms')

    if [[ -z "$success" || -z "$failed" || -z "$rating" || -z "$duration" ]]; then
        printf "Error: Summary extraction failed.\n" >&2
        return 1
    fi
    # Debug: Pokaż wyodrębnione dane podsumowania
    printf "DEBUG: Summary - Success: %s, Failed: %s, Rating: %s, Duration: %s\n" \
        "$success" "$failed" "$rating" "$duration"

    # Creating JSON
    {
        printf '{\n'
        printf '  "testName": "%s",\n' "$test_name"
        printf '  "tests": %s,\n' "$tests_json"
        printf '  "summary": {\n'
        printf '    "success": %s,\n' "$success"
        printf '    "failed": %s,\n' "$failed"
        printf '    "rating": %s,\n' "$rating"
        printf '    "duration": "%s"\n' "$duration"
        printf '  }\n'
        printf '}\n'
    } > "$output_file"

    # Wymuś spójność formatowania JSON
    if command -v jq >/dev/null 2>&1; then
        cat "$output_file" | jq --sort-keys . > tmp.json && mv tmp.json "$output_file"
    fi

    # Debug: Pokaż ostateczny JSON
    printf "DEBUG: Final output JSON:\n"
    cat "$output_file"
    printf "\n"

    printf "JSON output written to '%s'.\n" "$output_file"
}

main() {
    if [[ $# -ne 1 ]]; then
        printf "Usage: %s <path_to_output.txt>\n" "$(basename "$0")" >&2
        return 1
    fi

    local input_file=$1
    convert_to_json "$input_file"
}

main "$@"