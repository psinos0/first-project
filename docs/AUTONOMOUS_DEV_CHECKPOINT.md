# Autonomiczny checkpoint rozwoju

Data: 2026-10-08  
Gałąź: `feat/meatcraft-empire-3d`  
Ostatni commit funkcjonalny: `bb0b9ca` (`feat: build MeatCraft Empire 3D vertical slice`)

## Aktualny stan projektu

Główna scena uruchamia grywalny pionowy wycinek MeatCraft Empire w prawdziwym 3D. Gracz przechodzi od menu i zakupu małej hali przez wybór działalności, instalację linii, zakup wołowiny, pełną partię biltongu, kontrolę suszenia, pakowanie i wysyłkę. Interfejs działa po angielsku i po polsku, zapis v2 zachowuje aktywny proces, a stary prototyp 2D pozostaje w historii i przechodzi swoje testy regresji.

Aktywna faza to koniec fazy pierwszego pionowego wycinka i początek rozwoju systemów zarządzania fabryką. Ostatnim ukończonym kamieniem milowym jest zweryfikowany pełny obieg pierwszej partii w hali 3D.

## Ważne decyzje architektoniczne

- `MeatGame` jest autoloadem i jedynym właścicielem stanu ekonomii, zapasów, czasu, partii i zapisu.
- Warstwa 3D oraz UI obserwują sygnały stanu i nie naliczają zasobów samodzielnie.
- Balans i receptury są w `config/meatcraft_game.json`; teksty EN/PL w `assets/meatcraft_strings.csv`.
- Fabryka korzysta z lekkich prymitywów MeshInstance3D i własnego ArrayMesh dla mięsa, aby utrzymać zgodność z rendererem Compatibility.
- Test wizualny steruje prawdziwą sceną, symuluje cały proces i zapisuje rzeczywiste klatki z renderera.
- Wartości procesu i HACCP są jawnie opisane jako fikcyjna mechanika gry.

## Zmienione obszary

- `project.godot`, `scenes/meatcraft_main.tscn`
- `scripts/meatcraft/`
- `config/meatcraft_game.json`
- `assets/meatcraft_strings*`
- `scripts/tests/meatcraft_*`
- `docs/screenshots/`
- `README.md`, `docs/VALIDATION.md`, `docs/ROADMAP.md`
- `scripts/setup.sh`, `scripts/test.sh`

## Wykonana walidacja

- `./scripts/setup.sh`: import Godot 4.7.2 bez błędów projektu.
- `./scripts/test.sh`: regresja 2D **43/43**, symulacja MeatCraft **41/41**.
- Test OpenGL/Compatibility z Xorg dummy i Mesa llvmpipe: **21/21**.
- Oględziny aktualnych zrzutów 1280×800 i 960×540.
- Import i oba zestawy testów logiki powtórzone z czystej paczki `MeatCraft-Empire-3D.zip`.

Zweryfikowano zakup, koszty, dostawę, stany magazynowe, pełną maszynę stanów, kontrolę w 3,5. dniu, bilans masy, pakowanie, sprzedaż, konserwację, higienę, zapis/wczytanie, collidery 3D, polski interfejs i układ minimalny.

## Znane niepowodzenia i blokery

- Wirtualny sterownik graficzny ostrzega, że nie obsługuje zmiany V-Sync; test renderowania mimo tego przechodzi.
- Brak oficjalnych szablonów eksportu Godot 4.7.2 blokuje lokalne EXE i HTML5.
- Brak Android SDK, `adb` i Gradle blokuje debug APK oraz test urządzenia.
- Nie ma jeszcze pracowników z zadaniami, płacami i zmęczeniem, losowych awarii/napraw, incydentów jakości, swobodnego build mode ani postępu offline.

## Następna dokładna akcja

Zaimplementować pierwszy system pracowników: dane ról i płac w konfiguracji, przydział jednego pracownika do przygotowania/suszenia/pakowania, dzienny koszt, prostą kolejkę zadań, status w HUD, zapis v3 i testy braku podwójnego naliczania płac po wczytaniu.

## Polecenia środowiska

```sh
cd /workspace/first-project
./scripts/setup.sh
./scripts/test.sh
./scripts/run.sh
```

Test renderowania wymaga działającego wyświetlacza X11:

```sh
source scripts/env.sh
export DISPLAY=:90
export CRAFT_CAPTURE_DIR="$PWD/docs/screenshots"
"$CRAFT_GODOT" --path "$PWD" --audio-driver Dummy \
  --script res://scripts/tests/meatcraft_visual_test.gd
```

Przed dalszą pracą sprawdzić `git status`, pozostać na `feat/meatcraft-empire-3d` i nie scalać do `main` bez wyraźnej zgody.
