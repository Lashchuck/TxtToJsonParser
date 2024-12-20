#!/bin/bash

echo "DEBUG: Script started" >&2

if [ $# -lt 1 ]
then
    echo "Usage: ./task2.sh /path/to/output.txt"
    exit 0
fi

file=$1

if [ ! -f $file ]
then
    echo "File $file doesn't exist"
    exit 1
fi

path=$(dirname $file)

tests_started=0

echo "Processing file: $file" >&2

(cat $file; echo;) | while read -r line; do

    echo "DEBUG: Processing line: $line" >&2  # Log przetwarzania linii

    if [[ $line =~ ^\[ ]]
    then
        test_name_regexp='^\[ ([A-Za-z ]+) \], ([0-9]+)\.\.([0-9]+) ([a-zA-Z]+)'
        if [[ $line =~ $test_name_regexp ]]
        then
            test_name=${BASH_REMATCH[1]}
            first_test_id=${BASH_REMATCH[2]}
            last_test_id=${BASH_REMATCH[3]}
            test_cases_name=${BASH_REMATCH[4]}
            echo "Extracted test name: $test_name" >&2
            echo "{"
            echo "    \"testName\": \"$test_name\","
        else
            echo "Invalid format in test name line: $line" >&2
            exit 1
        fi
        continue
    fi

    if [[ $line =~ ^-+ ]]
    then
        if [ $tests_started -eq 0 ]
        then
            tests_started=1
            echo "    \"$test_cases_name\": ["
        else
            tests_started=0
            echo "    ],"
        fi
        continue
    fi

    if [ $tests_started -eq 1 ]
    then
        line=$(echo "$line" | tr -s ' ')
        test_regex='^(not ok|ok)[[:space:]]+([0-9]+)[[:space:]]+(.*)[[:space:]]*,[[:space:]]*([0-9]+ms)$'
        echo "DEBUG: Test line (normalized): $line" >&2
        echo "DEBUG: Regex: $test_regex" >&2
        if [[ $line =~ $test_regex ]]
        then
            status=${BASH_REMATCH[1]}
            id=${BASH_REMATCH[2]}
            name=${BASH_REMATCH[3]}
            duration=${BASH_REMATCH[4]}
            if [[ $status == "ok" ]]
            then
                status=true
            else
                status=false
            fi
            echo "Processing test case: Name=\"$name\", Status=\"$status\", Duration=\"$duration\"" >&2
            echo "        {"
            echo "            \"name\": \"$name\","
            echo "            \"status\": $status,"
            echo "            \"duration\": \"$duration\""

            if [ $id -eq $last_test_id ]
            then
                echo "        }"
            else
                echo "        },"
            fi
        else
            echo "DEBUG: Line does not match regex after normalization" >&2
            echo "Invalid format in test line: $line" >&2
            exit 1
        fi
        continue
    fi

    summary_regex='([0-9]+) \(of ([0-9]+)\) tests passed, ([0-9]+) tests failed, rated as ([0-9.]+)%, spent ([0-9msh]+)'
    if [[ $line =~ $summary_regex ]]
    then
        success=${BASH_REMATCH[1]}
        total=${BASH_REMATCH[2]}
        failed=${BASH_REMATCH[3]}
        rating=${BASH_REMATCH[4]}
        duration=${BASH_REMATCH[5]}
        echo "Generated summary: Success=$success, Failed=$failed, Rating=$rating%, Duration=$duration" >&2
        echo "    \"summary\": {"
        echo "        \"success\": $success,"
        echo "        \"failed\": $failed,"
        echo "        \"rating\": $rating,"
        echo "        \"duration\": \"$duration\""
        echo "    }"
        echo "}"

        break

    else
        echo "Invalid format in summary line: $line" >&2
        exit 1
    fi
done > $path/output.json

echo "DEBUG: Script completed successfully" >&2