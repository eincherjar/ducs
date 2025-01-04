# Skrypt do zarządzania konfiguracjami Django z Supervisor i Caddy

Ten skrypt umożliwia automatyczne tworzenie i usuwanie konfiguracji dla aplikacji Django działającej na serwerze z wykorzystaniem `Supervisor` oraz `Caddy`. Skrypt pozwala na konfigurację aplikacji Django pod kątem uruchamiania za pomocą `uvicorn` w środowisku wirtualnym oraz ustawienia serwera Caddy jako reverse proxy.

## Funkcje

- **Tworzenie konfiguracji Supervisor:**
  - Tworzenie pliku konfiguracyjnego dla aplikacji Django w Supervisor.
  - Automatyczne ustawienie użytkownika i grupy na podstawie folderu, w którym uruchomiony jest skrypt.
  - Ustalenie odpowiednich zmiennych środowiskowych, takich jak `PATH` i `VIRTUAL_ENV` dla środowiska wirtualnego.

- **Tworzenie konfiguracji Caddy:**
  - Tworzenie pliku konfiguracyjnego Caddy do obsługi aplikacji Django.
  - Konfiguracja ścieżek statycznych i mediów oraz reverse proxy do aplikacji uruchomionej na `uvicorn`.

- **Automatyczne dodanie użytkownika `caddy` do grupy właściciela folderu aplikacji.**

- **Usuwanie konfiguracji:**
  - Możliwość usunięcia konfiguracji Supervisor oraz Caddy.
  - Skrypt umożliwia usunięcie plików konfiguracyjnych oraz ponowne załadowanie ustawień w Supervisor i Caddy.

## Wymagania

- System operacyjny: Linux (Ubuntu lub inna dystrybucja oparta na Debianie).
- Zainstalowane pakiety:
  - `supervisor`:
    ```bash
      python -m pip install supervisor
    ```
  - `ufw` (opcjonalnie, do odblokowywania portów)
  - `caddy`:
    ```bash
      sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https curl
      curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
      curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
      sudo apt update
      sudo apt install caddy
    ```
  - `stat` (zwykle dostępny domyślnie)
  - `uvicorn`:
    ```bash
      python -m pip install uvicorn
    ```
- Wirtualne środowisko Python (np. `venv`).
- Uprawnienia root (do edycji plików konfiguracyjnych i dodawania użytkownika do grupy).

## Instalacja

1. Sklonuj repozytorium:
   ```bash
   git clone https://github.com/eincherjar/ducs.git
   ```
2. Upewnij się, że masz zainstalowane wymagane oprogramowanie (Supervisor, Caddy, etc.).
3. Przejdź do folderu z aplikacją Django i uruchom skrypt:
   ```bash
   cd /sciezka/do/aplikacji/django
   sudo /sciezka/do/skryptu/manage_django_app.sh
   ```
4. Wykonaj jedną z dostępnych opcji:
   - Tworzenie nowej konfiguracji
   - Usuwanie istniejącej konfiguracji

## Użycie

Po uruchomieniu skryptu, pojawi się interaktywne menu z następującymi opcjami:
1. **Utwórz nową konfigurację** — pozwala na skonfigurowanie aplikacji Django w Supervisor i Caddy.
2. **Usuń istniejącą konfigurację** — umożliwia usunięcie konfiguracji Supervisor i Caddy.
3. **Wyjdź** — kończy działanie skryptu.

## Przykład

Po uruchomieniu opcji 1 (utworzenie konfiguracji) skrypt poprosi o następujące dane:
  - Ścieżka do aplikacji Django.
  - Port, na którym aplikacja będzie działać.
  - Nazwa domeny.
  - Nazwa środowiska wirtualnego.
  - Nazwa aplikacji Supervisor.
  - Moduł aplikacji dla uvicorn.

Na podstawie tych informacji, skrypt automatycznie utworzy konfigurację zarówno dla Supervisor, jak i Caddy. Następnie doda użytkownika caddy do grupy właściciela folderu aplikacji.

## Uwagi

  - Skrypt działa tylko na systemach Linux, które mają zainstalowane wymagane pakiety.
  - Skrypt zakłada, że aplikacja Django jest uruchamiana za pomocą uvicorn w środowisku wirtualnym.
  - Użytkownik uruchamiający skrypt musi mieć uprawnienia do edycji konfiguracji systemowych oraz dodawania użytkowników do grup.
