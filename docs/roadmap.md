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
- Historia doświadczeń, trwałe wnioski oraz osobne poziomy i XP umiejętności.
- Widoki pamięci i rozwoju, zapis postępu i ograniczony skrót dla modelu.

## Wersja 0.4: życie osady
- Relacje, wzajemne decyzje dorosłych o rodzinie, ciąże, dzieci, dorastanie i nauka.
- Zdrowie, kontakt społeczny, miejsca w domach, cele i zawody wybierane przez AI.
- Wyczerpywanie jagód, uprawa i fizyczny transport plonów.
- Burze, wilki, schronienie, warta i leczenie z dostawą zapasów.
- Dziesięć ustawień świata, scenariusze zagrożeń i podgląd osady.
- Rotacja planowania w grupach 2/3/5 osób; test równoczesnych dostaw 20 NPC.
- Zapis dynamicznej populacji i rodzin, migracja starych danych.

## Następny etap: pomiar z prawdziwym lokalnym modelem
- Pomiary czasu decyzji, FPS i wykorzystania GPU na Windows.
- Ocena sensowności planów małego modelu i równowagi zapasów.
- Sprawdzenie pełnego pobierania runtime'u/modelu na czystym Windows.
- Dopiero po potwierdzeniu stabilności: dalsze rozszerzanie autonomii.

## Rozbudowa świata
- Podłączenie assetów, animacji pracy, kolizji i szukania ścieżek.
- Handel, waluta, własność domów, technologie i bardziej zróżnicowane budynki.
- Bardziej złożone wspólne projekty, zobowiązania i planowanie na wiele dni.

## Wydanie jako jedna aplikacja
- Automatyczne przygotowanie silnika i modelu jest obsługiwane przez grę na Windows.
- Pozostają eksport EXE, instalator i weryfikacja na komputerze bez narzędzi programistycznych.
- Wagi modeli pozostają poza repozytorium; aplikacja pobiera je lokalnie.
