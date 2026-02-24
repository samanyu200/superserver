#!/bin/bash

BASE="/mc-servers"
PORT_DB="$BASE/ports.db"
mkdir -p "$BASE"
touch "$PORT_DB"

install_deps() {
    if command -v apt >/dev/null 2>&1; then
        apt update -y >/dev/null 2>&1
        apt install -y openjdk-17-jre-headless wget curl screen unzip cpulimit >/dev/null 2>&1
    elif command -v yum >/dev/null 2>&1; then
        yum install -y java-17-openjdk wget curl screen unzip cpulimit >/dev/null 2>&1
    fi
}

get_ip() {
    curl -s ifconfig.me || curl -s ipinfo.io/ip || echo "Unknown-IP"
}

get_port() {
    for p in $(seq 25565 25665); do
        if ! grep -q "^$p$" "$PORT_DB"; then
            echo "$p" >> "$PORT_DB"
            echo "$p"
            return
        fi
    done
}

status_server() {
    if screen -list | grep -q "\.$1"; then
        echo "RUNNING"
    else
        echo "OFFLINE"
    fi
}

create_server() {
    clear
    echo "=== Create Server ==="
    read -p "Server Name: " NAME
    read -p "RAM (e.g 2G): " RAM
    read -p "CPU Limit % (e.g 50): " CPU
    read -p "Type (paper/vanilla/bedrock): " TYPE
    read -p "Version (e.g 1.20.4): " VERSION

    DIR="$BASE/$NAME"
    mkdir -p "$DIR"
    cd "$DIR" || exit

    PORT=$(get_port)

    if [ "$TYPE" = "paper" ]; then
        wget -q -O server.jar "https://api.papermc.io/v2/projects/paper/versions/$VERSION/builds/493/downloads/paper-$VERSION-493.jar"
        echo "java" > type.txt
    elif [ "$TYPE" = "vanilla" ]; then
        wget -q -O server.jar https://launcher.mojang.com/v1/objects/server.jar
        echo "java" > type.txt
    elif [ "$TYPE" = "bedrock" ]; then
        wget -q https://minecraft.azureedge.net/bin-linux/bedrock-server-1.20.40.02.zip
        unzip -o bedrock-server-*.zip >/dev/null
        chmod +x bedrock_server
        echo "bedrock" > type.txt
    else
        echo "Invalid type!"
        sleep 2
        return
    fi

    echo "eula=true" > eula.txt
    echo "$RAM" > ram.txt
    echo "$CPU" > cpu.txt
    echo "$PORT" > port.txt

    IP=$(get_ip)
    clear
    echo "=============================="
    echo "Server Created Successfully!"
    echo "Access IP: $IP:$PORT"
    echo "=============================="
    read -p "Press Enter..."
}

start_server() {
    clear
    echo "=== Start Server ==="
    ls "$BASE"
    read -p "Enter Server Name: " NAME
    DIR="$BASE/$NAME"

    if [ ! -d "$DIR" ]; then
        echo "Server not found!"
        sleep 2
        return
    fi

    if screen -list | grep -q "\.$NAME"; then
        echo "Server already running!"
        sleep 2
        return
    fi

    RAM=$(cat "$DIR/ram.txt")
    CPU=$(cat "$DIR/cpu.txt")
    TYPE=$(cat "$DIR/type.txt")
    PORT=$(cat "$DIR/port.txt")

    cd "$DIR" || exit

    if [ "$TYPE" = "java" ]; then
        screen -dmS "$NAME" bash -c "while true; do java -Xms$RAM -Xmx$RAM -jar server.jar nogui; echo 'Crash detected, restarting in 5s...'; sleep 5; done"
    else
        screen -dmS "$NAME" bash -c "while true; do ./bedrock_server; echo 'Crash detected, restarting in 5s...'; sleep 5; done"
    fi

    PID=$(pgrep -f "SCREEN.*$NAME" | head -n1)
    cpulimit -p "$PID" -l "$CPU" >/dev/null 2>&1 &

    IP=$(get_ip)
    echo "Server Started!"
    echo "IP: $IP:$PORT"
    read -p "Press Enter..."
}

stop_server() {
    clear
    echo "=== Stop Server ==="
    screen -list
    read -p "Enter Server Name to Stop: " NAME

    if ! screen -list | grep -q "\.$NAME"; then
        echo "Server is not running!"
        sleep 2
        return
    fi

    echo "Sending graceful stop command..."
    screen -S "$NAME" -p 0 -X stuff "stop$(printf '\r')"
    sleep 5

    if screen -list | grep -q "\.$NAME"; then
        echo "Force stopping server..."
        screen -S "$NAME" -X quit
    fi

    echo "Server Stopped Successfully!"
    sleep 2
}

delete_server() {
    clear
    echo "=== Delete Server ==="
    ls "$BASE"
    read -p "Enter Server Name: " NAME
    rm -rf "$BASE/$NAME"
    echo "Server Deleted!"
    sleep 2
}

list_servers() {
    clear
    echo "=== Server List ==="
    IP=$(get_ip)
    for s in $(ls "$BASE"); do
        if [ -d "$BASE/$s" ]; then
            STATUS=$(status_server "$s")
            PORT=$(cat "$BASE/$s/port.txt" 2>/dev/null)
            echo "$s | $STATUS | $IP:$PORT"
        fi
    done
    read -p "Press Enter..."
}

install_deps

while true; do
    clear
    echo "====== SUPER SERVER MENU ======"
    echo "1. Create Server"
    echo "2. Start Server"
    echo "3. Stop Server"
    echo "4. Delete Server"
    echo "5. List Servers (Status)"
    echo "6. Exit"
    echo "================================"
    read -p "Select Option: " opt

    case $opt in
        1) create_server ;;
        2) start_server ;;
        3) stop_server ;;
        4) delete_server ;;
        5) list_servers ;;
        6) exit ;;
        *) echo "Invalid Option"; sleep 1 ;;
    esac
done
