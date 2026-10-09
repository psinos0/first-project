# Walidacja MeatCraft Empire 3D

Silnik: **Godot 4.7.2 Stable**, `4.7.2.stable.official.ed1daf0bf`, Linux x86-64. Projekt używa renderera GL Compatibility.

## Wyniki automatyczne

- Import projektu w edytorze headless: sceny, GDScript, fonty, obrazy i tłumaczenia zostały zaimportowane.
- Regresja zachowanego prototypu 2D: **43 sprawdzenia, 0 niepowodzeń**.
- Symulacja MeatCraft 3D: **41 sprawdzeń, 0 niepowodzeń**.
- Systemy operacyjne Sprintu 02: **61 sprawdzeń, 0 niepowodzeń**.
- Integracja z rzeczywistym renderowaniem OpenGL przez Xorg dummy i Mesa llvmpipe: **41 sprawdzeń, 0 niepowodzeń**.
- Czysta paczka ZIP utworzona przez `git archive`: integralność archiwum, świeży import bez `.godot` oraz ponownie **43/43**, **41/41** i **61/61**.

Nowa symulacja sprawdza zakup hali i linii, koszty, blokady podwójnych działań, dostawę, zużycie składników, wszystkie etapy, obowiązkową kontrolę w połowie suszenia, bilans 10 kg → 9,4 kg → 4,7 kg → 94 × 50 g, pakowanie, jednokrotne naliczenie sprzedaży, deklaracje receptur, konserwację, czyszczenie oraz zapis i wznowienie aktywnego marynowania.

Pakiet operacyjny sprawdza rekrutację, unikalne identyfikatory, przydziały i ograniczenia ról, płace przy jednym i wielu przekroczonych okresach, brak podwójnego naliczenia po wczytaniu, zmęczenie i doświadczenie, blokadę produkcji bez operatora, deterministyczną awarię, koszt i części naprawy, zapis aktywnej naprawy, kwarantannę, zapis działania korygującego, zwolnienie partii, kontrakt bez przedwczesnego przychodu, dokładne zużycie 60 z 94 opakowań, jednokrotną wypłatę £261 oraz migrację v2 bez duplikowania zasobów.

Test wizualny sprawdza osiem wybieralnych obszarów urządzeń, 21 pasków mięsa, dwa wentylatory, widoczność zatrudnionej załogi, wybór suszarni przez collider 3D, prawdziwe zadanie pracownika, przewijane panele, kontrakt, kwarantannę, awarię i naprawę z technikiem, rzeczywisty przepływ zapasów, polskie tłumaczenie i brak nakładania paneli przy 960×540. Każdy zrzut jest wykonywany z aktualnego stanu gry, a nie z grafiki koncepcyjnej.

## Oględziny renderów

Sprawdzono menu, wybór nieruchomości, wyposażoną halę, aktywną linię, żywych pracowników, suszarnię, kontrolę w połowie cyklu, pakowanie, gotowe zamówienie, pracowników i płace, kontrakty, kwarantannę, awarię, naprawę oraz polski interfejs. Poprawiono zerową wysokość przewijanych paneli i wydłużono ujęcie naprawy, aby technik zdążył dotrzeć do stanowiska.

## Eksporty i platformy

- Linux w środowisku chmurowym: logika i renderowanie sprawdzone.
- Windows: projektu nie wyeksportowano ani nie uruchomiono jako EXE.
- Web/HTML5: projektu nie wyeksportowano ani nie uruchomiono w przeglądarce.
- Android: projektu nie wyeksportowano ani nie uruchomiono na urządzeniu.

Środowisko nie zawiera szablonów eksportu Godot 4.7.2. Nie ma również Android SDK, `adb` ani Gradle; dostępne środowisko Java samo nie wystarcza do wygenerowania APK. Katalog `builds/` jest przeznaczony na przyszłe lokalne artefakty i pozostaje poza repozytorium.

## Granice walidacji

- Mysz i rozdzielczość 960×540 zostały sprawdzone; dotyk, gesty, safe areas i uśpienie wymagają fizycznego telefonu lub tabletu.
- Nie wykonano pomiarów GPU, pamięci, czasu klatki ani zużycia baterii na sprzęcie docelowym.
- Dźwięk korzysta ze starszego systemu projektu i nie był odsłuchiwany w teście z wyjściem Dummy.
- HACCP, wydajność suszenia i czasy są mechaniką edukacyjnej gry, nie walidacją procesu spożywczego.
- Zmiany są skonfigurowane, ale pierwszy model zmianowy nie blokuje jeszcze pracownika poza godzinami zmiany; zmęczenie i regeneracja wpływają na stan oraz wydajność.
- Planowanie pokazuje bieżącą partię i kolejkę aktywnych zadań, ale nadal działa jedna aktywna partia i nie ma kolejki przyszłych zleceń produkcyjnych.
- Swobodny tryb budowy, wiele równoległych partii i postęp offline nie są jeszcze zaimplementowane.

Wyniki potwierdzają stabilny pionowy wycinek na sprawdzonej konfiguracji Linux. Nie oznaczają gotowości komercyjnej ani zgodności platform, których nie zbudowano.
