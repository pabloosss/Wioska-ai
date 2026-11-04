# Plan prac — Wioska AI

## Etap 1: podstawowa symulacja
- Pięciu mieszkańców, potrzeby, ruch i wybór pracy.
- Zbieranie jedzenia oraz drewna do wspólnego magazynu.
- Budowanie, prywatny ekwipunek i log zdarzeń.

## Etap 2: porządna pętla gry
- Ścieżki, animacje pracy i użycie wybranych assetów.
- Zapis/odczyt świata i potrzeb mieszkańców.
- Bilans produkcji, zużycia oraz temperatury.

## Etap 3: lokalne AI
- Połączenie z lokalnym Ollama API.
- Osobny profil i wspomnienia dla każdego NPC.
- Model wybiera zamiar, a symulacja waliduje akcję i zmienia świat.
- Decyzje podejmowane okresowo i po zdarzeniach, nie w każdej klatce.

## Etap 4: uruchamianie jako jedna aplikacja
- Instalator gry.
- Sprawdzenie lub przygotowanie silnika lokalnego AI.
- Pobranie modelu przy pierwszym uruchomieniu i jasny ekran postępu.
- Zapis gry i model pozostają lokalnie na komputerze gracza.

## Zasada
Kod gry i konfiguracja są w repozytorium. Wagi modelu AI nie są częścią repozytorium GitHub.
