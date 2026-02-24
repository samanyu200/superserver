#!/bin/bash

BASE_DIR="/root/mcservers"
USER_NAME="samanyu200"
REPO_NAME="superserver"

mkdir -p "$BASE_DIR"

get_public_ip() {
    curl -s ifconfig.me || curl -s api.ipify.org || echo "0.0.0.0"
}

get_free_port() {
    for port in 25565 25566 25567 25568 25569; do
        if ! lsof -i:$port >/dev/null 2>&1; then
            echo $port
            return
        fi
    done
    echo "25570"
}

server_exists() {
    [ -d "$BASE_DIR/$1" ]
}

is_running() {
    screen -list | grep -q "mc_$1"
}

create_server() {
    read -p "Server name: " NAME
    if server_exists "$NAME"; then
        echo "Server already exists."
        return
    fi

    mkdir -p "$BASE_DIR/$NAME"
    cd "$BASE_DIR/$NAME"

    echo "Select type:"
    echo "1) Paper (Java)"
    echo "2) Bedrock"
    read -p "Choice: " TYPE

    PORT=$(get_free_port)

    if [ "$TYPE" = "2" ]; then
        echo "Downloading Bedrock..."
        wget -q https://minecraft.azureedge.net/bin-linux/bedrock-server-1.21.0.03.zip -O bedrock.zip
        unzip -q bedrock.zip
        rm bedrock.zip
        echo "bedrock" > type.txt
        echo "$PORT" > port.txt
        echo "Created Bedrock server on port $PORT"
    else
        echo "Downloading Paper..."
        wget -q https://api.papermc.io/v2/projects/paper/versions/1.20.4/builds/416/downloads/paper-1.20.4-416.jar -O server.jar
        echo "eula=true" > eula.txt
        echo "java" > type.txt
        echo "$PORT" > port.txt
        echo "Created Paper server on port $PORT"
    fi
}

start_server() {
    read -p "Server name: " NAME
    if ! server_exists "$NAME"; then
        echo "Server not found."
        return
    fi

    if is_running "$NAME"; then
        echo "Server already running!"
        return
    fi

    cd "$BASE_DIR/$NAME"

    rm -f world/session.lock 2>/dev/null

    TYPE=$(cat type.txt)
    PORT=$(cat port.txt)
    IP=$(get_public_ip)

    echo "Starting server on $IP:$PORT"

    if [ "$TYPE" = "bedrock" ]; then
        screen -dmS "mc_$NAME" bash -c "./bedrock_server"
    else
        screen -dmS "mc_$NAME" bash -c '
        while true; do
            java -Xmx4G -Xms2G -jar server.jar --nogui
            echo "Crash detected. Restarting in 10 seconds..."
            sleep 10
        done'
    fi
}

stop_server() {
    read -p "Server name: " NAME
    if ! is_running "$NAME"; then
        echo "Server is not running."
        return
    fi

    screen -S "mc_$NAME" -X stuff "stop$(printf \\r)"
    sleep 5
    screen -S "mc_$NAME" -X quit
    echo "Server stopped safely."
}

show_console() {
    read -p "Server name: " NAME
    if ! is_running "$NAME"; then
        echo "Server is offline."
        return
    fi
    echo "Attaching to console (CTRL+A then D to detach)"
    screen -r "mc_$NAME"
}

list_servers() {
    echo "==== Server List ===="
    for dir in "$BASE_DIR"/*; do
        [ -d "$dir" ] || continue
        NAME=$(basename "$dir")
        PORT=$(cat "$dir/port.txt" 2>/dev/null)
        if is_running "$NAME"; then
            STATUS="RUNNING"
        else
            STATUS="OFFLINE"
        fi
        echo "$NAME | Port: $PORT | Status: $STATUS"
    done
}

delete_server() {
    read -p "Server name: " NAME
    if is_running "$NAME"; then
        echo "Stop the server first!"
        return
    fi
    rm -rf "$BASE_DIR/$NAME"
    echo "Server deleted."
}

while true; do
    echo ""
    echo "==== SUPER SERVER MENU ===="
    echo "1) Create Server"
    echo "2) Start Server (Background)"
    echo "3) Stop Server"
    echo "4) Show Console (Live)"
    echo "5) List Servers (Status)"
    echo "6) Delete Server"
    echo "7) Exit"
    read -p "Select option: " CHOICE

    case $CHOICE in
        1) create_server ;;
        2) start_server ;;
        3) stop_server ;;
        4) show_console ;;
        5) list_servers ;;
        6) delete_server ;;
        7) exit 0 ;;
        *) echo "Invalid option" ;;
    esac
done
