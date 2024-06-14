#!/usr/bin/with-contenv bashio

HOME_ASSISTANT_URL=http://supervisor/core
HOME_ASSISTANT_ACCESS_TOKEN=$SUPERVISOR_TOKEN

CONFIG_INCLUDE_DOMAINS=$(bashio::config 'include_domains' | jq --raw-input --compact-output --slurp 'split("\n")')
CONFIG_INCLUDE_PATTERNS=$(bashio::config 'include_patterns' | jq --raw-input --compact-output --slurp 'split("\n")')
CONFIG_EXCLUDE_DOMAINS=$(bashio::config 'exclude_domains' | jq --raw-input --compact-output --slurp 'split("\n")')
CONFIG_EXCLUDE_PATTERNS=$(bashio::config 'exclude_patterns' | jq --raw-input --compact-output --slurp 'split("\n")')

HOME_ASSISTANT_CLIENT_CONFIG=$(jq --null-input --compact-output \
  --argjson includeDomains "$CONFIG_INCLUDE_DOMAINS" \
  --argjson includePatterns "$CONFIG_INCLUDE_PATTERNS" \
  --argjson excludeDomains "$CONFIG_EXCLUDE_DOMAINS" \
  --argjson excludePatterns "$CONFIG_EXCLUDE_PATTERNS" \
  '{ "includeDomains": $includeDomains, "includePatterns": $includePatterns, "excludeDomains": $excludeDomains, "excludePatterns": $excludePatterns }'
)

echo "#############################"
echo "CURRENT CLIENT CONFIGURATION:"
echo "$HOME_ASSISTANT_CLIENT_CONFIG" | jq
echo "#############################"

export HOME_ASSISTANT_URL
export HOME_ASSISTANT_ACCESS_TOKEN
export HOME_ASSISTANT_CLIENT_CONFIG

# Install user configured plugins
if bashio::config.has_value 'plugins'; then
    bashio::log.info "Starting installation of custom NPM plugins..."
    for package in $(bashio::config 'plugins'); do
        npmlist+=("$package")
    done

    # install all packages together
    npm install --loglevel=verbose \
        "${npmlist[@]}" \
           || bashio::exit.nok "Failed to install a specified npm package"

    # then register each one
    for package in $(bashio::config 'plugins'); do
        npm run matterbridge -- -add "./node_modules/$package"
    done
fi

npm run matterbridge -- -add ./node_modules/matterbridge-home-assistant
npm run matterbridge -- -bridge -docker
