#!/usr/bin/env bash
set -euo pipefail

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
ENVIRONMENT_FILE="$CONFIG_HOME/polybar/weather.env"
[[ -r "$ENVIRONMENT_FILE" ]] && source "$ENVIRONMENT_FILE"

get_icon() {
    case $1 in
        01d) icon="🟠";;
        01n) icon="⚫";;
        02d) icon="⛅";;
        02n) icon="⛅";;
        04d) icon="🌥️";;
        04n) icon="🌥️";;
        09d) icon="🌧️";;
        09n) icon="🌧️";;
        10d) icon="🌦️";;
        10n) icon="🌦️";;
        11d) icon="🌩️";;
        11n) icon="🌩️";;
        13d) icon="❄️";;
        13n) icon="❄️";;
        50d) icon="🌫️";;
        50n) icon="🌫️";;
        *) icon="☁️";
    esac

    echo $icon
}

get_duration() {

    osname=$(uname -s)

    case $osname in
        *BSD) date -r "$1" -u +%H:%M;;
        *) date --date="@$1" -u +%H:%M;;
    esac

}

KEY="${OPENWEATHER_API_KEY:-}"
CITY="${OPENWEATHER_CITY:-}"
LATITUDE="${OPENWEATHER_LAT:-}"
LONGITUDE="${OPENWEATHER_LON:-}"
UNITS="${OPENWEATHER_UNITS:-metric}"
SYMBOL="${OPENWEATHER_SYMBOL:-°}"

API="https://api.openweathermap.org/data/2.5"

if [[ -z "$KEY" ]]; then
    printf 'WEATHER: add a key to ~/.config/polybar/weather.env\n'
    exit 0
fi

if [[ -n "$CITY" ]]; then
    if [[ "$CITY" =~ ^[0-9]+$ ]]; then
        CITY_PARAM="id=$CITY"
    else
        CITY_PARAM="q=$CITY"
    fi

    current=$(curl -sf "$API/weather?appid=$KEY&$CITY_PARAM&units=$UNITS")
    #curl -s "https://api.openweathermap.org/data/2.5/onecall?lat=0&lon=0&appid=TOKEN&units=metric" | jq -r '.daily[1].temp.day'
    forecast=$(curl -sf "$API/forecast?appid=$KEY&$CITY_PARAM&units=$UNITS&cnt=1")
elif [[ -n "$LATITUDE" && -n "$LONGITUDE" ]]; then
    current=$(curl -sf "$API/weather?appid=$KEY&lat=$LATITUDE&lon=$LONGITUDE&units=$UNITS")
    forecast=$(curl -sf "$API/forecast?appid=$KEY&lat=$LATITUDE&lon=$LONGITUDE&units=$UNITS&cnt=1")
else
    printf 'WEATHER: set OPENWEATHER_CITY or latitude/longitude\n'
    exit 0
fi

if [[ -n "$current" && -n "$forecast" ]]; then
    current_temp=$(jq -r '.main.temp | round' <<< "$current")
    current_icon=$(echo "$current" | jq -r ".weather[0].icon")

    forecast_temp=$(jq -r '.list[0].main.temp | round' <<< "$forecast")
    forecast_icon=$(echo "$forecast" | jq -r ".list[].weather[0].icon")

    sun_rise=$(echo "$current" | jq ".sys.sunrise")
    sun_set=$(echo "$current" | jq ".sys.sunset")
    now=$(date +%s)

    if [ "$sun_rise" -gt "$now" ]; then
        daytime="🌅 $(get_duration "$((sun_rise-now))")"
    elif [ "$sun_set" -gt "$now" ]; then
        daytime="🌇 $(get_duration "$((sun_set-now))")"
    else
        daytime="🌙"
    fi

    printf '%s %s%s %s %s%s  %s\n' \
        "$(get_icon "$current_icon")" "$current_temp" "$SYMBOL" \
        "$(get_icon "$forecast_icon")" "$forecast_temp" "$SYMBOL" "$daytime"
fi
