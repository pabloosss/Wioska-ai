# Wioska AI — prototyp

Projekt Godot 4 z automatycznym przygotowaniem lokalnego AI.

## Uruchomienie

1. Zainstaluj Godot 4 i otwórz projekt z `game/project.godot`.
2. Naciśnij **F5**.
3. Przy pierwszym uruchomieniu gra sprawdzi, czy Ollama już działa. Jeśli nie, sama pobierze przenośny runtime, uruchomi go i pobierze model `qwen3.5:35b`.

Nie musisz osobno instalować Ollamy ani ręcznie pobierać modelu. Pierwsze przygotowanie wymaga internetu i wolnego miejsca na dysku. Model 35B zajmuje dużo miejsca, a pobieranie może potrwać.

## Sterowanie

- **Spacja** — pauza/wznowienie.
- **1–5** albo kliknięcie mieszkańca — wybór postaci.
- **R** — ponowne sprawdzenie i wznowienie przygotowania AI.

## Jak działa AI

- Jeden lokalny model obsługuje wszystkich mieszkańców; gra wysyła ich profile w jednym zapytaniu co 2 godziny czasu w grze.
- Każda postać ma osobny charakter, potrzeby, pracę, umiejętności i ostatnie wspomnienia.
- Model wybiera zamiar: pracować, jeść, odpocząć albo się ogrzać. Gra sprawdza zamiar i wykonuje ruch oraz zmianę zasobów.
- Pilne potrzeby są zabezpieczane przez symulację, nawet jeśli odpowiedź AI się spóźni lub będzie niedostępna.
- Wspomnienia, umiejętności, potrzeby i stan wioski zapisują się lokalnie w danych użytkownika.

## Ograniczenia prototypu

Automatyczne pobieranie runtime'u Ollamy i modelu jest przygotowane dla Windows. Gra działa obecnie z poziomu edytora Godot; samodzielny instalator/plik EXE do udostępniania powstanie w kolejnym etapie. Wagi modelu nie są częścią repozytorium.
