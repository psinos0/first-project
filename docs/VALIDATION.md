# Walidacja pierwszego grywalnego etapu

Silnik: **Godot 4.7.2 Stable**, `4.7.2.stable.official.ed1daf0bf`, Linux x86-64. Oficjalne archiwum zweryfikowano przy użyciu pliku SHA512-SUMS z wydania Godot.

## Wykonane sprawdzenia

- Import przez `--headless --editor --import`: zasoby, sceny, fonty, tłumaczenia i składnia GDScript.
- Uruchomienie głównej sceny w trybie headless.
- Testy w osobnym profilu danych: **43 sprawdzenia, 0 niepowodzeń**.
- Test z renderowaniem OpenGL/Compatibility przez Xorg dummy/Mesa llvmpipe: **0 niepowodzeń**. Symulowane zdarzenia myszy otworzyły warsztat, uruchomiły partię i wybrały maszynę.
- Oględziny wyrenderowanego menu, warsztatu, produkcji, ustawień, języka polskiego i szerszego układu. Poprawiono kolejność warstw modalnych oraz odstęp między warsztatem a dolnym panelem.
- Powtórne wykonanie skryptu instalacyjnego i testowego.
- Czysta kopia bez `.godot` i metadanych Git: import zakończony bez błędów, ponownie **43/43** sprawdzenia. Projekt nie wymaga istniejącej pamięci importu.
- Uruchomienie w oknie 960×540 i szerszym układzie 1600×900: warsztat i panele mieszczą się na ekranie. Ocena rozmiaru celów dotyku na fizycznym telefonie pozostaje do wykonania.

Testy obejmują koszty składników, blokadę podwójnego uruchomienia, wszystkie etapy oraz transport, sprzedaż dokładnie raz, ulepszenia, niezmienność parametrów aktywnej partii, rezerwę na składniki, duże kroki czasu, rangi, zapis aktywnej produkcji, odczyt ustawień, kopię zapasową, uszkodzony JSON, niepoprawne typy pól, ograniczenie danych, New Game, przyciski interfejsu, współrzędne dotyku/myszy, menu oraz symulację uśpienia/wznowienia.

## Granice walidacji

- Zdarzenia dotyku i powiadomienia uśpienia symulowano w Godot; nie testowano ich na fizycznym urządzeniu.
- Nie wykonano testów Android/iOS ani Windows, eksportu APK/EXE, podpisywania ani publikacji w sklepie.
- Nie zmierzono wydajności ani zużycia baterii na telefonie. Obraz testowano przy użyciu renderowania programowego na Linux.
- Efekty dźwiękowe są syntezowane w grze; headless nie odtwarza dźwięku. Test graficzny korzystał z wyjścia Dummy, więc nie oceniono odsłuchu na urządzeniu.
- Sterownik testowy zgłasza brak obsługi zmiany V-Sync. To ograniczenie wirtualnego wyświetlacza.
- Aktualna wersja nie ma przyrostu offline ani automatycznej kolejki partii. Produkcja poza warsztatem jest celowo wstrzymana.

Te wyniki potwierdzają grywalność sceny i logiki prototypu w sprawdzonym środowisku, a nie gotowość do publikacji komercyjnej.
