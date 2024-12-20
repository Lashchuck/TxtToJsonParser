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

    local test_name
    test_name=$(grep -oP '(?<=\[ ).*(?= \])' "$input_file")
    if [[ -z "$test_name" ]]; then
        printf "Error: Unable to extract test name.\n" >&2
        return 1
    fi

    local tests_json
    tests_json=$(grep -P '^(ok|not ok)' "$input_file" | \
        awk '
        BEGIN { print "[" }
        {
            status = ($1 == "ok") ? "true" : "false"
            name = ""
            for (i = 3; i <= NF - 2; i++) name = name " " $i
            name = name " " $(NF - 1)  # Add the second last field for the full name
            gsub(/^\s*[0-9]+\s/, "", name)  # Remove leading test numbers
            gsub(/^ /, "", name)            # Trim leading space
            gsub(/, $/, "", name)           # Remove trailing comma in name
            printf "{\"name\":\"%s\",\"status\":%s,\"duration\":\"%s\"},\n", name, status, $NF
        }
        END { print "]" }
        ' | sed 's/\),"/)","/g' | sed ':a;N;$!ba;s/,\n]/\n]/')

    if [[ -z "$tests_json" ]]; then
        printf "Error: Unable to extract test details.\n" >&2
        return 1
    fi

    local summary_line
    summary_line=$(grep -oP '\d+ \(.+?tests passed, .+?tests failed.+?$' "$input_file")
    if [[ -z "$summary_line" ]]; then
        printf "Error: Unable to extract summary.\n" >&2
        return 1
    fi

    local success failed rating duration
    success=$(echo "$summary_line" | grep -oP '^\d+(?= \(of)')
    failed=$(echo "$summary_line" | grep -oP '(?<=, )\d+(?= tests failed)')
    rating=$(echo "$summary_line" | grep -oP '\d+(\.\d+)?(?=%)')
    duration=$(echo "$summary_line" | grep -oP '(?<=spent )\d+ms')

    if [[ -z "$success" || -z "$failed" || -z "$rating" || -z "$duration" ]]; then
        printf "Error: Summary extraction failed.\n" >&2
        return 1
    fi

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