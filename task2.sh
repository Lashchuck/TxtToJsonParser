#!/bin/bash

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

(cat $file; echo;) | while read -r line; do

    echo "DEBUG: Processing line: $line" >&2  # Debug

    if [[ $line =~ ^\[ ]]
    then
        test_name_regexp='^\[ ([A-Za-z ]+) \], ([0-9]+)\.\.([0-9]+) ([a-zA-Z]+)'
        if [[ $line =~ $test_name_regexp ]]
        then
            test_name=${BASH_REMATCH[1]}
            first_test_id=${BASH_REMATCH[2]}
            last_test_id=${BASH_REMATCH[3]}
            test_cases_name=${BASH_REMATCH[4]}
            echo "{"
            echo "    \"testName\": \"$test_name\","
        else
            echo "Invalid format in test name line: $line" 1>&2
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
              # Normalize spaces in the line
              line=$(echo "$line" | tr -s ' ')
              test_regex='^(not ok|ok)[[:space:]]+([0-9]+)[[:space:]]+(.*)[[:space:]]*,[[:space:]]*([0-9]+ms)$'
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

                  if [ $id -eq $last_test_id ]
                  then
                      echo "        }"
                  else
                      echo "        },"
                  fi
              else
                  exit 1
              fi
              continue
          fi

    # tests_finished: getting summary
    summary_regex='([0-9]+) \(of ([0-9]+)\) tests passed, ([0-9]+) tests failed, rated as ([0-9.]+)%, spent ([0-9msh]+)'
    if [[ $line =~ $summary_regex ]]
    then
        success=${BASH_REMATCH[1]}
        total=${BASH_REMATCH[2]}
        failed=${BASH_REMATCH[3]}
        rating=${BASH_REMATCH[4]}
        duration=${BASH_REMATCH[5]}

        echo "    \"summary\": {"
        echo "        \"success\": $success,"
        echo "        \"failed\": $failed,"
        echo "        \"total\": $total,"
        echo "        \"rating\": $rating,"
        echo "        \"duration\": \"$duration\""
        echo "    }"
        echo "}"

        break

    else
        echo "Invalid format in summary line: $line" 1>&2
        exit 1
    fi
done > $path/output.json