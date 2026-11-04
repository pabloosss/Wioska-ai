# Wioska AI — prototyp

Projekt Godot 4 z lokalnym połączeniem z Ollamą.

## Uruchomienie

1. Uruchom Ollamę i upewnij się, że jest pobrany model `qwen3.5:35b`.
2. Zainstaluj Godot 4.
3. W Godot wybierz **Importuj** i wskaż `game/project.godot`.
4. Otwórz projekt i naciśnij **F5**.

Jeśli Ollama jest wyłączona lub modelu nie ma, gra pokaże status w prawym panelu, a mieszkańcy będą korzystać z prostych zachowań awaryjnych. **R** ponawia sprawdzenie Ollamy.

## Sterowanie

- **Spacja** — pauza/wznowienie.
- **1–5** albo kliknięcie mieszkańca — wybór postaci.
- **R** — ponowne sprawdzenie lokalnego AI.

## Jak działa AI

- Jeden lokalny model obsługuje wszystkich mieszkańców; gra wysyła ich profile w jednym zapytaniu co 2 godziny czasu w grze.
- Każda postać ma osobny charakter, potrzeby, pracę, umiejętności i ostatnie wspomnienia.
- Model wybiera zamiar: pracować, jeść, odpocząć albo się ogrzać. Gra sprawdza zamiar i wykonuje ruch oraz zmianę zasobów.
- Pilne potrzeby są zabezpieczane przez symulację, nawet jeśli odpowiedź AI się spóźni lub będzie niedostępna.
- Wspomnienia, umiejętności, potrzeby i stan wioski zapisują się lokalnie w danych użytkownika.

## Ograniczenia prototypu

Grafika jest zastępcza, a Ollama i model muszą być obecnie zainstalowane osobno. Instalator, który przygotuje je automatycznie, powstanie później. Wagi modelu nie są przechowywane w repozytorium.
