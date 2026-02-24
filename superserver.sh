#!/bin/bash

BASE_DIR="$HOME/mcservers"
mkdir -p "$BASE_DIR"

# ===== PUBLIC IP DETECT =====
PUBLIC_IP=$(curl -s ifconfig.me)
if [[ -z "$PUBLIC_IP" ]]; then
  PUBLIC_IP=$(hostname -I | awk '{print $1}')
fi

# ===== AUTO PORT FINDER =====
get_free_port() {
  PORT=25565
  while lsof -i:$PORT >/dev/null 2>&1; do
    PORT=$((PORT+1))
  done
  echo $PORT
}

# ===== SERVER CREATOR =====
create_server() {
  read -p "Server name: " NAME
  read -p "Type (paper/bedrock): " TYPE
  read -p "RAM (ex: 4G): " RAM
  read -p "CPU cores (ex: 2): " CPU

  PORT=$(get_free_port)

  SERVER_DIR="$BASE_DIR/$NAME"
  mkdir -p "$SERVER_DIR"
  cd "$SERVER_DIR"

  echo "$PORT" > port.txt
  echo "$TYPE" > type.txt
  echo "$RAM" > ram.txt
  echo "$CPU" > cpu.txt

  if [[ "$TYPE" == "paper" ]]; then
    echo "Downloading latest Paper..."
    curl -L -o server.jar https://api.papermc.io/v2/projects/paper/versions/1.20.4/builds/416/downloads/paper-1.20.4-416.jar
    echo "eula=true" > eula.txt
  fi

  if [[ "$TYPE" == "bedrock" ]]; then
    echo "Download Bedrock manually and place in this folder."
  fi

  echo "Server created!"
  echo "Connect with: $PUBLIC_IP:$PORT"
}

# ===== START SERVER =====
start_server() {
  read -p "Server name: " NAME
  SERVER_DIR="$BASE_DIR/$NAME"

  if [[ ! -d "$SERVER_DIR" ]]; then
    echo "Server not found."
    return
  fi

  cd "$SERVER_DIR"

  TYPE=$(cat type.txt)
  RAM=$(cat ram.txt)
  CPU=$(cat cpu.txt)
  PORT=$(cat port.txt)

  if [[ "$TYPE" == "paper" ]]; then

    if [[ ! -f server.jar ]]; then
      echo "server.jar missing!"
      return
    fi

    if ! jar tf server.jar >/dev/null 2>&1; then
      echo "server.jar is invalid!"
      return
    fi

    echo "Starting Paper server..."
    taskset -c 0-$((CPU-1)) bash -c "
      while true; do
        java -Xms$RAM -Xmx$RAM -jar server.jar --nogui
        echo 'Crash detected. Restarting in 5 seconds...'
        sleep 5
      done
    " &
    echo $! > pid.txt
  fi

  if [[ "$TYPE" == "bedrock" ]]; then
    chmod +x bedrock_server
    ./bedrock_server &
    echo $! > pid.txt
  fi

  echo "Server running at $PUBLIC_IP:$PORT"
}

# ===== STOP SERVER =====
stop_server() {
  read -p "Server name: " NAME
  SERVER_DIR="$BASE_DIR/$NAME"

  if [[ -f "$SERVER_DIR/pid.txt" ]]; then
    PID=$(cat "$SERVER_DIR/pid.txt")
    kill $PID
    rm "$SERVER_DIR/pid.txt"
    echo "Server stopped."
  else
    echo "Server not running."
  fi
}

# ===== SHOW CONSOLE =====
show_console() {
  read -p "Server name: " NAME
  SERVER_DIR="$BASE_DIR/$NAME"
  cd "$SERVER_DIR"

  TYPE=$(cat type.txt)
  RAM=$(cat ram.txt)

  if [[ "$TYPE" == "paper" ]]; then
    java -Xms$RAM -Xmx$RAM -jar server.jar --nogui
  fi

  if [[ "$TYPE" == "bedrock" ]]; then
    ./bedrock_server
  fi
}

# ===== LIST SERVERS =====
list_servers() {
  echo "===== SERVER LIST ====="
  for DIR in "$BASE_DIR"/*; do
    if [[ -d "$DIR" ]]; then
      NAME=$(basename "$DIR")
      PORT=$(cat "$DIR/port.txt")
      if [[ -f "$DIR/pid.txt" ]]; then
        STATUS="RUNNING"
      else
        STATUS="OFFLINE"
      fi
      echo "$NAME - $STATUS - $PUBLIC_IP:$PORT"
    fi
  done
}

# ===== MENU =====
while true; do
  echo ""
  echo "====== SUPER SERVER ======"
  echo "1) Create Server"
  echo "2) Start Server"
  echo "3) Stop Server"
  echo "4) Show Console"
  echo "5) List Servers"
  echo "6) Exit"
  read -p "Choose: " OPTION

  case $OPTION in
    1) create_server ;;
    2) start_server ;;
    3) stop_server ;;
    4) show_console ;;
    5) list_servers ;;
    6) exit ;;
    *) echo "Invalid option" ;;
  esac
done
