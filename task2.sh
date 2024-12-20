#!/bin/bash

set -o pipefail
set -e

# Sprawdzenie, czy użytkownik podał ścieżkę do pliku jako argument.
if [ $# -lt 1 ]; then
    printf "Usage: ./task2.sh /path/to/output.txt\n" >&2
    exit 0
fi

# Przypisanie pierwszego argumentu do zmiennej `file`.
file=$1

# Sprawdzenie, czy podany plik istnieje.
if [ ! -f "$file" ]; then
    printf "File %s doesn't exist\n" "$file" >&2
    exit 1
fi

# Ustalenie katalogu pliku wejściowego i zdefiniowanie ścieżki do pliku wyjściowego JSON.
path=$(dirname "$file")
output_file="$path/output.json"

# Zainicjowanie flagi informującej, czy trwa przetwarzanie przypadków testowych.
tests_started=0

{
    # Rozpoczęcie tworzenia pliku JSON.
    printf "{\n"

    # Odczytywanie pliku wejściowego linia po linii.
    (cat "$file"; echo;) | while read -r line; do
        printf "DEBUG: Processing line: %s\n" "$line" >&2

        if [[ $line =~ ^\[ ]]; then
            test_name_regexp='^\[ ([A-Za-z ]+) \], ([0-9]+)\.\.([0-9]+) ([a-zA-Z]+)'
            if [[ $line =~ $test_name_regexp ]]; then
                # Wyodrębnianie metadanych
                test_name=${BASH_REMATCH[1]}
                first_test_id=${BASH_REMATCH[2]}
                last_test_id=${BASH_REMATCH[3]}
                test_cases_name=${BASH_REMATCH[4]}
                printf "DEBUG: Extracted test name: %s\n" "$test_name" >&2
                printf "    \"testName\": \"%s\",\n" "$test_name"
            else
                # Przerwanie działania, jeśli format linii jest nieprawidłowy.
                printf "Invalid format in test name line: %s\n" "$line" >&2
                exit 1
            fi
            continue
        fi

        if [[ $line =~ ^-+ ]]; then
            if [ $tests_started -eq 0 ]; then
                tests_started=1
                printf "DEBUG: Starting test case parsing.\n" >&2
                printf "    \"tests\": [\n"
            else
                tests_started=0
                printf "DEBUG: Finished test case parsing.\n" >&2
                printf "    ],\n"
            fi
            continue
        fi

        if [ $tests_started -eq 1 ]; then
            line=$(echo "$line" | tr -s ' ')
            test_regex='^(not ok|ok)[[:space:]]+([0-9]+)[[:space:]]+(.*)[[:space:]]*,[[:space:]]*([0-9]+ms)$'
            printf "DEBUG: Test line (normalized): %s\n" "$line" >&2
            printf "DEBUG: Regex: %s\n" "$test_regex" >&2
            if [[ $line =~ $test_regex ]]; then
                # Wyodrębnianie szczegółów testu: status, ID, nazwa i czas trwania.
                status=${BASH_REMATCH[1]}
                id=${BASH_REMATCH[2]}
                name=${BASH_REMATCH[3]}
                duration=${BASH_REMATCH[4]}
                # Konwersja "ok" na true i "not ok" na false do formatu JSON.
                if [[ $status == "ok" ]]; then
                    status=true
                else
                    status=false
                fi
                # Wyjście JSON dla bieżącego przypadku testowego.
                printf "DEBUG: Processing test case: Name=\"%s\", Status=\"%s\", Duration=\"%s\"\n" "$name" "$status" "$duration" >&2
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
                # Przerwanie działania, jeśli format linii jest nieprawidłowy.
                printf "DEBUG: Line does not match regex after normalization\n" >&2
                printf "Invalid format in test line: %s\n" "$line" >&2
                exit 1
            fi
            continue
        fi

        # Przetwarzanie linii podsumowania zawierającej wyniki i metadane.
        summary_regex='([0-9]+) \(of ([0-9]+)\) tests passed, ([0-9]+) tests failed, rated as ([0-9.]+)%, spent ([0-9msh]+)'
        if [[ $line =~ $summary_regex ]]; then
            # Wyodrębnianie szczegółów podsumowania: liczba sukcesów, błędów, ocena i czas.
            success=${BASH_REMATCH[1]}
            total=${BASH_REMATCH[2]}
            failed=${BASH_REMATCH[3]}
            rating=${BASH_REMATCH[4]}
            duration=${BASH_REMATCH[5]}
            printf "DEBUG: Generated summary: Success=%s, Failed=%s, Rating=%s%%, Duration=%s\n" "$success" "$failed" "$rating" "$duration" >&2
            # Wyjście JSON dla podsumowania.
            printf "    \"summary\": {\n"
            printf "        \"success\": %s,\n" "$success"
            printf "        \"failed\": %s,\n" "$failed"
            printf "        \"rating\": %s,\n" "$rating"
            printf "        \"duration\": \"%s\"\n" "$duration"
            printf "    }\n"
            printf "}\n"
            break
        else
            # Przerwanie działania, jeśli format linii podsumowania jest nieprawidłowy.
            printf "Invalid format in summary line: %s\n" "$line" >&2
            exit 1
        fi
    done

} > "$output_file"

# Sprawdzenie, czy plik JSON został pomyślnie utworzony.
if [ -f "$output_file" ]; then
    printf "DEBUG: JSON file successfully created at: %s\n" "$output_file" >&2
else
    printf "DEBUG: Failed to create JSON file at: %s\n" "$output_file" >&2
    exit 1
fi
