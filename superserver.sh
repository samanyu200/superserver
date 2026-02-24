#!/bin/bash

BASE_DIR="/root/mcservers"
mkdir -p "$BASE_DIR"

# -------- PAPER VERSION DATA --------
PAPER_LATEST="1.21.11"
PAPER_URL="https://fill-data.papermc.io/v1/objects/e708e8c132dc143ffd73528cccb9532e2eb17628b1a0eee74469bf466c7003f8/paper-1.21.11-116.jar"

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

    PORT=$(get_free_port)

    echo "Downloading Paper $PAPER_LATEST..."
    curl -L -o server.jar "$PAPER_URL"

    if [ ! -f server.jar ]; then
        echo "Download failed. Jar not found."
        return
    fi

    echo "eula=true" > eula.txt
    echo "java" > type.txt
    echo "$PORT" > port.txt

    cat > server.properties <<EOF
server-ip=0.0.0.0
server-port=$PORT
motd=SuperServer Node
online-mode=true
enable-command-block=true
EOF

    echo "Server created on port $PORT"
}

start_server() {
    read -p "Server name: " NAME
    if ! server_exists "$NAME"; then
        echo "Server not found."
        return
    fi

    if is_running "$NAME"; then
        echo "Already running."
        return
    fi

    cd "$BASE_DIR/$NAME"

    rm -f world/session.lock 2>/dev/null

    PORT=$(cat port.txt)
    IP=$(get_public_ip)

    echo "Starting server on 0.0.0.0:$PORT (Public: $IP:$PORT)"

    screen -dmS "mc_$NAME" bash -c '
    while true; do
        java -Xmx4G -Xms2G -jar server.jar --nogui
        echo "Crash detected. Restarting in 10s..."
        sleep 10
    done'
}

stop_server() {
    read -p "Server name: " NAME
    if ! is_running "$NAME"; then
        echo "Server not running."
        return
    fi

    screen -S "mc_$NAME" -X stuff "stop$(printf \\r)"
    sleep 5
    screen -S "mc_$NAME" -X quit
    echo "Stopped."
}

show_console() {
    read -p "Server name: " NAME
    if ! is_running "$NAME"; then
        echo "Server offline."
        return
    fi
    screen -r "mc_$NAME"
}

list_servers() {
    echo "==== SERVERS ===="
    for dir in "$BASE_DIR"/*; do
        [ -d "$dir" ] || continue
        NAME=$(basename "$dir")
        PORT=$(cat "$dir/port.txt" 2>/dev/null)
        if is_running "$NAME"; then
            STATUS="RUNNING"
        else
            STATUS="OFFLINE"
        fi
        echo "$NAME | Port: $PORT | $STATUS"
    done
}

delete_server() {
    read -p "Server name: " NAME
    if is_running "$NAME"; then
        echo "Stop server first."
        return
    fi
    rm -rf "$BASE_DIR/$NAME"
    echo "Deleted."
}

while true; do
    echo ""
    echo "==== SUPER SERVER ===="
    echo "1) Create"
    echo "2) Start"
    echo "3) Stop"
    echo "4) Console"
    echo "5) List"
    echo "6) Delete"
    echo "7) Exit"
    read -p "Choice: " CH

    case $CH in
        1) create_server ;;
        2) start_server ;;
        3) stop_server ;;
        4) show_console ;;
        5) list_servers ;;
        6) delete_server ;;
        7) exit ;;
        *) echo "Invalid" ;;
    esac
done
