# Autonomiczny checkpoint rozwoju

Data: 2026-10-09

Gałąź: `feat/meatcraft-operations-systems`

Baza integracyjna: `feat/meatcraft-empire-3d` (`462efa1`)

Ostatni commit funkcjonalny: `c973c0e` (`feat: add factory operations management systems`)

## Aktualny kamień milowy

Sprint 02 dostarczył połączone z symulacją zarządzanie załogą, maszynami, jakością i kontraktami. Pracownik wykonuje autorytatywne zadanie, maszyna może zatrzymać etap awarią, technik naprawia ją za pieniądze i część, incydent HACCP blokuje partię lub gotowy towar, a kontrakt wypłaca przychód dopiero po prawidłowej wysyłce. Dotychczasowy pełny obieg 10 kg → 94 opakowania nadal działa.

Aktywna faza to zakończenie stabilnego zakresu operacyjnego oraz przygotowanie kolejnego etapu: prawdziwej kolejki produkcyjnej, egzekwowania zmian i trybu rozmieszczania urządzeń.

## Zaimplementowane funkcje

- Cztery role, limit ośmiu etatów, koszty zatrudnienia, płace, zwalnianie z potwierdzeniem i zmiana przypisanej maszyny.
- Rekordy pracowników z trwałym ID, umiejętnością, doświadczeniem, wydajnością, zmęczeniem, morale, statusem, zadaniem i zmianą.
- Kolejka zadań manualnych, przydział według roli, jeden właściciel wyniku zadania i czytelny powód blokady produkcji.
- Trzyosobowa załoga startowa, która nie tworzy ekonomicznego soft-locka.
- Płace według monotonicznych okresów czasu gry, dług płacowy przy braku gotówki i historia transakcji bez podwójnego naliczania po wczytaniu.
- Indywidualny stan sześciu maszyn: kondycja, zużycie, godziny, awaria, przestój, część, koszt, czas naprawy i historia.
- Techniczne naprawy jako zapisane, czasowe zadania pracownika; produkcja wznawia się po zakończeniu dokładnie raz.
- Incydenty jakości, wstrzymane partie, działania korygujące, zwolnienie partii oraz historia partii i inspekcji.
- Trzy kontrakty z terminami i wymaganym SKU; przyjęcie nie daje pieniędzy, wysyłka zużywa właściwy zapas i płaci jeden raz.
- Księga finansowa z kategoriami przychodów i wydatków.
- Pracownicy 3D idą do przypisanych stanowisk, a światła i etykiety maszyn pokazują pracę, awarię i naprawę.
- Panele Planning, Employees, Contracts, HACCP i Finance oraz rozbudowany panel maszyny w EN/PL.

## Architektura i zapis

- `MeatGame` pozostaje autorytatywnym właścicielem stanu i koordynuje osobne klasy `WorkforceSystem`, `MachineSystem`, `QualitySystem` i `ContractSystem`.
- UI i scena 3D obserwują stan; nie naliczają zasobów ani wyników zadań.
- Konfiguracja v3 w `config/meatcraft_game.json` zawiera role, płace, maszyny, awarie, incydenty i kontrakty.
- Aktualny zapis to `user://meatcraft_v3.json` z kopią `.bak`.
- Wczytanie istniejącego v2 tworzy pełny stan v3 i zapisuje go w nowej lokalizacji bez modyfikowania oryginału v2.
- Migracja zachowuje pieniądze, magazyn i aktywną produkcję oraz dodaje działającą załogę, maszyny, jakość, kontrakty i historię.

## Zmienione obszary

- `scripts/meatcraft/workforce_system.gd`
- `scripts/meatcraft/machine_system.gd`
- `scripts/meatcraft/quality_system.gd`
- `scripts/meatcraft/contract_system.gd`
- `scripts/meatcraft/meat_game.gd`
- `scripts/meatcraft/factory_3d.gd`
- `scripts/meatcraft/meatcraft_ui.gd`
- `config/meatcraft_game.json`
- `assets/meatcraft_strings*`
- `scripts/tests/meatcraft_operations_test.gd`
- `scripts/tests/meatcraft_visual_test.gd`
- `docs/screenshots/`

## Wykonana walidacja

- Godot 4.7.2 Stable: `4.7.2.stable.official.ed1daf0bf`.
- `./scripts/test.sh`: regresja 2D **43/43**, podstawowa symulacja MeatCraft **41/41**, operacje Sprintu 02 **61/61**.
- Test renderowania OpenGL Compatibility na Xorg dummy i Mesa llvmpipe: **41/41**.
- Czyste archiwum Git: sprawdzona integralność, świeży import i ponownie wszystkie **145/145** testów logiki.
- Oględziny zrzutów 1280×800 i 960×540: panele mają zawartość, pracownicy są widoczni, technik dociera do awarii, stany maszyn i alerty są czytelne.
- Test kontraktu potwierdza 94 → 34 opakowania i £261 przychodu po wysyłce 60 sztuk.
- Test migracji potwierdza brak nadpisania v2 oraz brak duplikacji pieniędzy i zapasów po zapisie i ponownym wczytaniu v3.

## Znane ograniczenia i blokery

- Pola zmian i regeneracja istnieją, ale dostępność poza godzinami zmiany nie blokuje jeszcze przydziału. Ten fragment jest częściowy.
- Panel Planning pokazuje aktywną partię i zadania; kolejka przyszłych partii i wiele równoległych partii nie są zaimplementowane.
- Swobodny tryb budowy i rozmieszczanie urządzeń nie są zaimplementowane.
- Kontrakty mają terminy, ale nie naliczają jeszcze osobnej kary za spóźnienie ani wymogu minimalnej jakości.
- Wirtualny sterownik graficzny zgłasza oczekiwane ostrzeżenie o braku zmiany V-Sync; renderowanie przechodzi.
- Brak oficjalnych szablonów eksportu Godot 4.7.2 blokuje lokalne EXE i Web. Brak Android SDK, `adb` i Gradle blokuje APK i test urządzenia.

## Następna dokładna akcja

Najpierw wprowadzić kolejkę przyszłych partii jako osobne rekordy z trwałymi ID, wymaganym SKU, masą i priorytetem, bez zmiany autorytatywnego bilansu pojedynczej aktywnej partii. Następnie egzekwować godziny zmian przy wyborze pracownika i pokazywać w Planning przewidywany czas oczekiwania. Dodać test przekazania pierwszej ukończonej partii do następnej pozycji kolejki, zapis/wczytanie kolejki oraz przypadek braku pracownika na zmianie.

## Polecenia środowiska

```sh
cd /workspace/first-project
./scripts/setup.sh
./scripts/test.sh
./scripts/run.sh
```

Test renderowania przy działającym X11:

```sh
source scripts/env.sh
export DISPLAY=:90
export CRAFT_CAPTURE_DIR="$PWD/docs/screenshots"
"$CRAFT_GODOT" --path "$PWD" --audio-driver Dummy \
  --script res://scripts/tests/meatcraft_visual_test.gd
```

Przed dalszą pracą sprawdzić `git status --short --branch`, pozostać na `feat/meatcraft-operations-systems` i nie scalać do `main` bez wyraźnej zgody.
