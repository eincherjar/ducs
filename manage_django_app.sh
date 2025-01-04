#!/bin/bash

# Rozbudowany skrypt do zarządzania konfiguracjami Django (tworzenie i usuwanie)

CADDY_CONF_DIR="/etc/caddy/"
SUPERVISOR_CONF_DIR="/etc/supervisor/conf.d/"

check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "Proszę uruchomić skrypt jako root."
        exit 1
    fi
}

create_folder_if_missing() {
    local folder_path="$1"
    if [ ! -d "$folder_path" ]; then
        mkdir -p "$folder_path"
    fi
}

open_port_if_needed() {
    local port="$1"
    if command -v ufw &> /dev/null; then
        if ! ufw status | grep -qw "$port"; then
            echo "Odblokowywanie portu $port w UFW..."
            ufw allow "$port"
        fi
    fi
}

add_caddy_to_group() {
    local app_dir="$1"
    # Sprawdzenie, która grupa jest właścicielem folderu
    OWNER_GROUP=$(stat -c "%G" "$app_dir")
    if [ -n "$OWNER_GROUP" ]; then
        echo "Grupa właściciela folderu $app_dir: $OWNER_GROUP"
        # Dodanie użytkownika caddy do tej grupy
        usermod -a -G "$OWNER_GROUP" caddy
        echo "Użytkownik 'caddy' został dodany do grupy $OWNER_GROUP"
    else
        echo "Nie udało się pobrać grupy właściciela folderu $app_dir"
    fi
}

get_user_and_group() {
    # Pobranie właściciela folderu
    APP_USER=$(stat -c "%U" "$1")
    APP_GROUP=$(stat -c "%G" "$1")
    echo "Użytkownik: $APP_USER"
    echo "Grupa: $APP_GROUP"
}

create_configuration() {
    # Pobranie bieżącego katalogu
    DEFAULT_APP_DIR=$(pwd)

    # Pobranie danych od użytkownika
    read -p "Podaj pełną ścieżkę do aplikacji Django [domyślnie: ${DEFAULT_APP_DIR}]: " APP_DIR
    APP_DIR=${APP_DIR:-$DEFAULT_APP_DIR}

    get_user_and_group "$APP_DIR"

    read -p "Podaj port, na którym ma działać aplikacja: " APP_PORT
    read -p "Podaj nazwę domeny (np. example.com): " APP_DOMAIN
    read -p "Podaj nazwę środowiska wirtualnego (np. venv): " VENV_NAME
    read -p "Podaj nazwę aplikacji dla Supervisor (np. MyApp): " APP_NAME
    read -p "Podaj nazwę modułu dla Uvicorn (np. core): " UVICORN_MODULE

    LOG_DIR="${APP_DIR}/log"
    create_folder_if_missing "$LOG_DIR"

    SUPERVISOR_CONF="${SUPERVISOR_CONF_DIR}/${APP_NAME}.conf"
    CADDY_SITE_CONF="${CADDY_CONF_DIR}/${APP_NAME}.Caddyfile"

    # Tworzenie konfiguracji Supervisor
    echo "Tworzenie konfiguracji Supervisor w $SUPERVISOR_CONF..."
    cat > "$SUPERVISOR_CONF" <<EOL
[program:${APP_NAME}]
command=${APP_DIR}/${VENV_NAME}/bin/uvicorn ${UVICORN_MODULE}.asgi:application --host 127.0.0.1 --port ${APP_PORT} --workers 4 --reload
directory=${APP_DIR}
autostart=true
autorestart=true
stderr_logfile=/var/log/${APP_NAME}.err.log
stdout_logfile=/var/log/${APP_NAME}.out.log
user=${APP_USER}
group=${APP_GROUP}
environment=PATH="${APP_DIR}/${VENV_NAME}/bin",VIRTUAL_ENV="${APP_DIR}/${VENV_NAME}"
EOL

    # Restartowanie Supervisor
    supervisorctl reread
    supervisorctl update
    supervisorctl start "$APP_NAME"

    # Tworzenie konfiguracji Caddy
    echo "Tworzenie konfiguracji Caddy w $CADDY_SITE_CONF..."
    cat > "$CADDY_SITE_CONF" <<EOL
${APP_DOMAIN} {
    encode zstd gzip

    handle_path /static/* {
        root * ${APP_DIR}/static/
        file_server
    }

    handle_path /media/* {
        root * ${APP_DIR}/media/
        file_server
    }

    handle {
        reverse_proxy 127.0.0.1:${APP_PORT}
    }
}
EOL

    # Sprawdzanie i aktualizacja głównego pliku Caddy
    CADDY_MAIN_CONF="/etc/caddy/Caddyfile"
    if ! grep -q "import ${CADDY_CONF_DIR}/*.Caddyfile" "$CADDY_MAIN_CONF"; then
        echo "Dodawanie importu do głównego pliku Caddy..."
        echo "import ${CADDY_CONF_DIR}/*.Caddyfile" >> "$CADDY_MAIN_CONF"
    fi

    # Restartowanie Caddy
    systemctl restart caddy

    # Odblokowywanie portu
    open_port_if_needed "$APP_PORT"

    # Dodanie użytkownika caddy do grupy właściciela folderu
    add_caddy_to_group "$APP_DIR"

    # Wyświetlenie podsumowania
    echo "Konfiguracja zakończona dla aplikacji ${APP_NAME}."
}

delete_configuration() {
    echo "Dostępne pliki konfiguracji Supervisor:"
    ls "${SUPERVISOR_CONF_DIR}" | grep -E "\.conf$"

    read -p "Podaj nazwę konfiguracji Supervisor do usunięcia (np. MyApp): " APP_NAME

    SUPERVISOR_CONF="${SUPERVISOR_CONF_DIR}/${APP_NAME}.conf"
    if [ -f "$SUPERVISOR_CONF" ]; then
        echo "Usuwanie konfiguracji Supervisor: ${SUPERVISOR_CONF}..."
        rm "$SUPERVISOR_CONF"
        supervisorctl reread
        supervisorctl update
    else
        echo "Nie znaleziono konfiguracji Supervisor dla aplikacji ${APP_NAME}."
    fi

    echo "Dostępne pliki konfiguracji Caddy:"
    ls "${CADDY_CONF_DIR}" | grep -E "\.Caddyfile$"

    read -p "Podaj nazwę konfiguracji Caddy do usunięcia (np. MyApp.Caddyfile): " CADDY_FILE
    CADDY_SITE_CONF="${CADDY_CONF_DIR}/${CADDY_FILE}"

    if [ -f "$CADDY_SITE_CONF" ]; then
        echo "Usuwanie konfiguracji Caddy: ${CADDY_SITE_CONF}..."
        rm "$CADDY_SITE_CONF"
        systemctl restart caddy
    else
        echo "Nie znaleziono konfiguracji Caddy dla pliku ${CADDY_FILE}."
    fi

    echo "Usunięcie zakończone."
}

main_menu() {
    echo "Zarządzanie konfiguracją Django"
    echo "1. Utwórz nową konfigurację"
    echo "2. Usuń istniejącą konfigurację"
    echo "3. Wyjdź"

    read -p "Wybierz opcję: " choice
    case $choice in
        1) create_configuration ;;
        2) delete_configuration ;;
        3) exit 0 ;;
        *) echo "Nieprawidłowa opcja." ;;
    esac
}

# Sprawdzanie uprawnień roota
check_root

# Wywołanie menu głównego
main_menu
