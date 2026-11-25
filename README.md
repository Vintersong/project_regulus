# Regulus

A Qix/Volfied-style territory-capture game. Twelve levels, one per zodiac sign. Each level hides an engraved celestial plate, which is revealed as you claim the field.

Built with Flutter and [Flame](https://flame-engine.org). Desktop (Windows) comes first; the web build also plays on phones. Landscape only.

## Run

```
flutter pub get
flutter run -d windows
flutter test
```

## Controls

| | Keyboard | Touch |
|---|---|---|
| Move | Arrow keys / WASD | D-pad (slide the thumb) |
| Cut | Hold Shift or Z | Hold CUT |
| Use item | Space | ITEM |
| Continue | Space / Enter | Tap the result screen |
| Tutorial | Esc skips, T replays | SKIP / TUTORIAL buttons |

The web build works on phones. Touch controls appear on the first touch (or on
Android/iOS from the start) and give way to the keyboard on the first key press.
They sit in side columns next to the game, not over it. In portrait the game
pauses behind a "rotate your device" prompt. On iPhone, Add to Home Screen gives
the fullscreen view.

## Layout

```
lib/
  main.dart                    app shell: GameWidget + touch controls
  game/
    regulus_game.dart          FlameGame, fixed-resolution camera (1280x800)
    input_mode.dart            touch vs keyboard, and the on-screen wording
    config.dart                grid + layout constants
    palette.dart               placeholder colours
    components/                game components (playfield, player, enemies…)
  ui/
    touch_controls.dart        D-pad, CUT / ITEM buttons, rotate prompt
assets/
  plates/                      12 zodiac plate images
  shaders/                     fragment shaders (plate shine)
docs/
  design.md                    game design notes
  art-direction.md             visual brief
```

Status: private, work in progress.
