# Plan prac — Wioska AI

## Etap 1: podstawowa symulacja
- Pięciu mieszkańców, potrzeby, ruch i wybór pracy.
- Zbieranie jedzenia oraz drewna, fizyczny transport do wspólnego magazynu.
- Budowanie, prywatny ekwipunek i log zdarzeń.

## Etap 2: porządna pętla gry
- Ścieżki, animacje pracy i użycie wybranych assetów.
- Dopracowanie ekonomii oraz temperatury.
- Rozbudowa zapisów i obsługi świata.

## Etap 3: lokalne AI — pierwsza integracja dodana
- Połączenie z lokalnym Ollama API i modelem `qwen3.5:35b`.
- Jeden model podejmuje decyzje dla pięciu NPC w osobnym kontekście każdej postaci.
- Profile, potrzeby i ostatnie wspomnienia są przekazywane do AI.
- Symulacja waliduje decyzje, obsługuje pilne potrzeby i zapisuje pamięć oraz postęp umiejętności.
- Do sprawdzenia w Godot z uruchomioną Ollamą.

## Etap 4: uruchamianie jako jedna aplikacja
- Przygotowanie runtime'u Ollamy i pobieranie modelu przy pierwszym uruchomieniu są obsługiwane przez grę na Windows.
- Dopracowanie ekranu postępu, ponawiania i błędów instalacji.
- Eksport gry do samodzielnego instalatora/EXE, aby gracz nie musiał otwierać projektu w edytorze Godot.
- Zapis gry i model pozostają lokalnie na komputerze gracza.

## Zasada
Kod gry i konfiguracja są w repozytorium. Wagi modelu AI nie są częścią repozytorium GitHub.
