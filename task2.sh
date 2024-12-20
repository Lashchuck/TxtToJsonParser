#!/bin/bash

set -o pipefail
set -e

convert_to_json(){
  local input_file=$1
  local jq_path="./jq"
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
    {
      status = ($1 == "ok") ? "true" : "false"
      name = $3
      for (i = 4; i <= NF - 2; i++) name = name " " $i
      duration = $(NF)
      printf "{\"name\":\"%s\",\"status\":%s,\"duration\":\"%s\"},", name, status, duration
    }' | sed 's/,$//')

  if [[ -z "$tests_json" ]]; then
    printf "Error: Unable to extract test details.\n" >&2
    return 1
  fi

  local summary_line
  summary_line=$(grep -oP '^\d+ \(.+?tests passed, .+?tests failed.+?$' "$input_file")
  if [[ -z "$summary_line" ]]; then
    printf "Error: Unable to extract summary.\n" >&2
    return
  fi

  local success failed rating duration
  success=$(echo "$summary_line" | grep -oP '^\d+(?= \(of)')
  failed=$(echo "$summary_line" | grep -oP '(?<=, )\d+(?= tests failed)')
  rating=$(echo "$summary_line" | grep -oP '\d+(\.\d+)?(?=%, rated as)')
  duration=$(echo "$summary_line" | grep -oP '(?<=spent )\d+ms')

  if [[ -z "$success" || -z "$failed" || -z "$rating" || -z "$duration" ]]; then
    printf "Error: Summary extraction failed.\n" >&2
    return 1
  fi

  printf '{"testName":"%s","tests":[%s],"summary":{"success":%s,"failed":%s,"rating":%s,"duration":"%s"}}\n' \
    "$test_name" "$tests_json" "$success" "$failed" "$rating" "$duration" | \
    "$jq_path" '.' > "$output_file"

  printf "JSON output written to '%s'.\n" "$output_file"
}

main(){
  if [[ $# -ne 1 ]]; then
    printf "Usage:  %s <path_to_output.txt>\n" "$(basename "$0")" >&2
    return 1
  fi

  local input_file=$1
  convert_to_json="$input_file"
}

main "$@"