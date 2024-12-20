#!/bin/bash

set -o pipefail
set -e

printf "DEBUG: Script started\n"

if [ $# -lt 1 ]; then
    printf "Usage: ./task2.sh /path/to/output.txt\n"
    exit 0
fi

file=$1

if [ ! -f "$file" ]; then
    printf "File $file doesn't exist\n"
    exit 1
fi

path=$(dirname "$file")

tests_started=0

printf "Processing file: %s\n" "$file"

(cat "$file"; echo;) | while read -r line; do

    printf "DEBUG: Processing line: %s\n" "$line"

    if [[ $line =~ ^\[ ]]; then
        test_name_regexp='^\[ ([A-Za-z ]+) \], ([0-9]+)\.\.([0-9]+) ([a-zA-Z]+)'
        if [[ $line =~ $test_name_regexp ]]; then
            test_name=${BASH_REMATCH[1]}
            first_test_id=${BASH_REMATCH[2]}
            last_test_id=${BASH_REMATCH[3]}
            test_cases_name=${BASH_REMATCH[4]}
            printf "DEBUG: Extracted test name: %s\n" "$test_name"
            printf "{\n"
            printf "    \"testName\": \"%s\",\n" "$test_name"
        else
            printf "Invalid format in test name line: %s\n" "$line"
            exit 1
        fi
        continue
    fi

    if [[ $line =~ ^-+ ]]; then
        if [ $tests_started -eq 0 ]; then
            tests_started=1
            printf "DEBUG: Starting test case parsing.\n"
            printf "    \"%s\": [\n" "$test_cases_name"
        else
            tests_started=0
            printf "DEBUG: Finished test case parsing.\n"
            printf "    ],\n"
        fi
        continue
    fi

    if [ $tests_started -eq 1 ]; then
        line=$(echo "$line" | tr -s ' ')
        test_regex='^(not ok|ok)[[:space:]]+([0-9]+)[[:space:]]+(.*)[[:space:]]*,[[:space:]]*([0-9]+ms)$'
        printf "DEBUG: Test line (normalized): %s\n" "$line"
        printf "DEBUG: Regex: %s\n" "$test_regex"
        if [[ $line =~ $test_regex ]]; then
            status=${BASH_REMATCH[1]}
            id=${BASH_REMATCH[2]}
            name=${BASH_REMATCH[3]}
            duration=${BASH_REMATCH[4]}
            if [[ $status == "ok" ]]; then
                status=true
            else
                status=false
            fi
            printf "DEBUG: Processing test case: Name=\"%s\", Status=\"%s\", Duration=\"%s\"\n" "$name" "$status" "$duration"
            printf "        {\n"
            printf "            \"name\": \"%s\",\n" "$name"
            printf "            \"status\": %s,\n" "$status"
            printf "            \"duration\": \"%s\"\n" "$duration"

            if [ $id -eq $last_test_id ]; then
                printf "        }\n"
            else
                printf "        },\n"
            fi
        else
            printf "DEBUG: Line does not match regex after normalization\n"
            printf "Invalid format in test line: %s\n" "$line"
            exit 1
        fi
        continue
    fi

    summary_regex='([0-9]+) \(of ([0-9]+)\) tests passed, ([0-9]+) tests failed, rated as ([0-9.]+)%, spent ([0-9msh]+)'
    if [[ $line =~ $summary_regex ]]; then
        success=${BASH_REMATCH[1]}
        total=${BASH_REMATCH[2]}
        failed=${BASH_REMATCH[3]}
        rating=${BASH_REMATCH[4]}
        duration=${BASH_REMATCH[5]}
        printf "DEBUG: Generated summary: Success=%s, Failed=%s, Rating=%s%%, Duration=%s\n" "$success" "$failed" "$rating" "$duration"
        printf "    \"summary\": {\n"
        printf "        \"success\": %s,\n" "$success"
        printf "        \"failed\": %s,\n" "$failed"
        printf "        \"rating\": %s,\n" "$rating"
        printf "        \"duration\": \"%s\"\n" "$duration"
        printf "    }\n"
        printf "}\n"
        break
    else
        printf "Invalid format in summary line: %s\n" "$line"
        exit 1
    fi
done > "$path/output.json"

printf "DEBUG: Script completed successfully\n"