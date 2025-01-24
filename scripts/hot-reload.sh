#!/bin/env bash
# Watch openresty and db source directories for changes using `fswatch` and hot reload configuration
echo -e "\e[1;34m[Openresty]\e[0m Watching source files in 'openresty/' for changes..."
echo -e "\e[1;32m[Database]\e[0m Watching source files in 'db/' for changes..."
batch_events=()
openresty_changed=false
db_changed=false

# get the pids of the openresty and postgrest processes from the process compose REST API
openresty_pid=$(curl -s http://localhost:8080/process/openresty-receptdb | jq '.pid')
postgrest_pid=$(curl -s http://localhost:8080/process/postgrest | jq '.pid')

echo -e "\e[1;34m[Openresty]\e[0m PID: $openresty_pid"
echo -e "\e[1;32m[Database]\e[0m PID: $postgrest_pid"

fswatch -0 --batch-marker=batch openresty db | while read -rd "" event; do
	if [[ "$event" == "batch" ]]; then
		# Process the batch
		if $openresty_changed; then
			echo -e "\e[1;34m[Openresty]\e[0m Source files in 'openresty/' have changed. Reloading configuration..."
			# docker compose kill -s SIGHUP openresty
			kill -s SIGHUP "$openresty_pid"
		fi
		if $db_changed; then
			echo -e "\e[1;32m[Database]\e[0m Source files in 'db/' have changed. Reloading configuration..."
			./scripts/reload_db.sh
			# docker compose kill -s SIGUSR1 postgrest
			kill -s SIGUSR1 "$postgrest_pid"
		fi

		# Reset for the next batch
		batch_events=()
		openresty_changed=false
		db_changed=false
	else
		# Add event to batch
		batch_events+=("$event")

		# Check if openresty or db directory changed
		if [[ "$event" == *"/openresty/"* ]]; then
			openresty_changed=true
		elif [[ "$event" == *"/db/"* ]]; then
			db_changed=true
		fi
	fi
done
