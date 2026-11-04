# Wioska AI

Projekt lokalnej symulacji wioski z autonomicznymi mieszkańcami. Każdy NPC ma własne potrzeby, charakter, umiejętności, ekwipunek i pamięć. Jeden lokalny model AI podejmuje decyzje mieszkańców, a symulacja wykonuje ruch i pracę zgodnie z zasadami świata.

## Status

Wersja 0.3 dodaje trwałe wnioski mieszkańców, historię doświadczeń i rozwój trzech umiejętności z realnym wpływem na szybkość pracy. Nowy panel ma paski potrzeb i XP oraz zakładki pamięci i rozwoju. Program oddziela symulację, wykonawcę planów AI, połączenie z Ollamą i interfejs. Pięciu mieszkańców wykonuje skończone zadania: zbiór obejmuje fizyczną dostawę, a spóźniona odpowiedź modelu nie przerywa pracy. Stały pasek pokazuje prawdziwy status AI, ostatni przyjęty plan i FPS. Przy pierwszym uruchomieniu gra sama przygotowuje runtime Ollamy i pobiera model. Osobny instalator gry oraz finalny eksport programu pozostają do zrobienia.

## Struktura

- `game/` — projekt Godot 4 i prototyp symulacji.
- `game/scripts/ollama_bridge.gd` — połączenie z lokalnym Ollama API.
- `assets/medieval-village-2.5d/` — paczka wioski z uprawami i animacjami pracy.
- `assets/fantasy-village-adventurers/` — alternatywny zestaw postaci, terenu i budynków.
- `assets/forest-foraging-icons/` — ikony jedzenia i przedmiotów do zbierania.
- `docs/project-design.md` — założenia projektu.
- `docs/roadmap.md` — etapy dalszej pracy.

Uruchomienie i wymagania AI opisuje [game/README.md](game/README.md).

## Ważne: licencje assetów

Każda paczka ma własną licencję. Repozytorium zawiera surowe pliki assetów, więc przed publicznym udostępnianiem sprawdź ograniczenia licencji. Jeśli repo ma pozostać publiczne, część surowych paczek może wymagać usunięcia lub przeniesienia do prywatnego repozytorium.
