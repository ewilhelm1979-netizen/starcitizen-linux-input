#!/usr/bin/env bash

sc_privacy_filter_json() {
  local mode="$1"
  if [[ "$mode" == "private" ]]; then
    jq --sort-keys '.'
    return
  fi
  [[ "$mode" == "public" ]] || sc_die 64 "privacy mode must be public or private"
  jq --sort-keys '
    walk(
      if type == "object" then
        with_entries(select(.key | test("runtimeId|path|serial|guid|hostname|username|environment|token|aclExcerpt"; "i") | not))
      elif type == "string" then
        gsub("/home/[^/[:space:]]+"; "[REDACTED_HOME]")
        | gsub("\\{[0-9A-Fa-f-]{16,}\\}"; "[REDACTED_GUID]")
      else . end
    )'
}
