# Walidacja MeatCraft Empire 3D

Silnik: **Godot 4.7.2 Stable**, `4.7.2.stable.official.ed1daf0bf`, Linux x86-64. Projekt używa renderera GL Compatibility.

## Wyniki automatyczne

- Import projektu w edytorze headless: sceny, GDScript, fonty, obrazy i tłumaczenia zostały zaimportowane.
- Regresja zachowanego prototypu 2D: **43 sprawdzenia, 0 niepowodzeń**.
- Symulacja MeatCraft 3D: **41 sprawdzeń, 0 niepowodzeń**.
- Integracja z rzeczywistym renderowaniem OpenGL przez Xorg dummy i Mesa llvmpipe: **21 sprawdzeń, 0 niepowodzeń**.

Nowa symulacja sprawdza zakup hali i linii, koszty, blokady podwójnych działań, dostawę, zużycie składników, wszystkie etapy, obowiązkową kontrolę w połowie suszenia, bilans 10 kg → 9,4 kg → 4,7 kg → 94 × 50 g, pakowanie, jednokrotne naliczenie sprzedaży, deklaracje receptur, konserwację, czyszczenie oraz zapis i wznowienie aktywnego marynowania.

Test wizualny sprawdza osiem wybieralnych obszarów urządzeń, 21 pasków mięsa, dwa wentylatory, trzech pracowników, wybór suszarni przez collider 3D, rzeczywisty przepływ zapasów, polskie tłumaczenie i brak nakładania paneli przy 960×540. Każdy zrzut jest wykonywany z aktualnego stanu gry, a nie z grafiki koncepcyjnej.

## Oględziny renderów

Sprawdzono menu, wybór nieruchomości, pustą i wyposażoną halę, aktywną linię, suszarnię, kontrolę w połowie cyklu, pakowanie, gotowe zamówienie i polski interfejs. W trakcie przeglądu poprawiono ekspozycję, położenie kamery, czytelność stref, górny HUD oraz konstrukcję komory, aby haki i mięso były widoczne.

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
- Obecna wersja nie zawiera jeszcze swobodnego trybu budowy, zatrudniania załogi, losowych awarii, incydentów jakości ani postępu offline.

Wyniki potwierdzają stabilny pionowy wycinek na sprawdzonej konfiguracji Linux. Nie oznaczają gotowości komercyjnej ani zgodności platform, których nie zbudowano.
