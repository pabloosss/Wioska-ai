# Plan prac — Wioska AI

## Wersja 0.2: przebudowana podstawa
- Oddzielny wykonawca skończonych zadań, symulacja 20 Hz i interfejs 4 Hz.
- AI planuje do trzech kolejnych działań; nowe i spóźnione odpowiedzi nie przerywają trwającej dostawy.
- Pięć postaci, potrzeby, zbiór, fizyczne dostawy, pojedyncze posiłki i etapy budowy.
- Stały status AI z czasem żądania, ostatnim przyjętym planem i FPS.
- Lekki model dla nowych instalacji i przycisk jego pobrania dla istniejących użytkowników.
- Autozapis i kopia poprzedniego zapisu; wczytywanie starszych danych.
- Testy pełnych cykli pracy oraz integracja z opóźnionymi, błędnymi i przekraczającymi limit odpowiedziami HTTP.

## Wersja 0.3: pamięć i rozwój
- Trwałe wnioski i liczniki doświadczeń, 40 ostatnich zdarzeń na mieszkańca.
- Ograniczony skrót pamięci i poziomy umiejętności przekazywane do AI.
- Zbieractwo, drwalstwo i budowanie: niezależne XP, poziomy 1–10 i szybsza praca.
- Zapis i migracja starych poziomów oraz wspomnień.
- Odświeżony motyw UI, karty zasobów, paski potrzeb/XP i osobne zakładki pamięci oraz rozwoju.

## Następny etap: pomiar z prawdziwym lokalnym modelem
- Pomiary czasu decyzji, FPS i wykorzystania GPU na Windows.
- Ocena sensowności planów małego modelu i równowagi zapasów.
- Sprawdzenie pełnego pobierania runtime'u/modelu na czystym Windows.
- Dopiero po potwierdzeniu stabilności: dalsze rozszerzanie autonomii.

## Rozbudowa świata
- Podłączenie assetów, animacji pracy, kolizji i szukania ścieżek.
- Ekonomia, specjalizacje, relacje, rozwój populacji i technologie.
- Relacje i przekazywanie wiedzy między mieszkańcami; rozwijanie obecnego systemu pamięci.

## Wydanie jako jedna aplikacja
- Automatyczne przygotowanie silnika i modelu jest obsługiwane przez grę na Windows.
- Pozostają eksport EXE, instalator i weryfikacja na komputerze bez narzędzi programistycznych.
- Wagi modeli pozostają poza repozytorium; aplikacja pobiera je lokalnie.
