# Regulus

A Qix/Volfied-style territory-capture game. Twelve levels, one per zodiac sign. Each level hides an engraved celestial plate, which is revealed as you claim the field.

Built with Flutter and [Flame](https://flame-engine.org). Desktop (Windows) comes first and mobile later. Landscape only.

## Run

```
flutter pub get
flutter run -d windows
flutter test
```

## Layout

```
lib/
  main.dart                    app shell + GameWidget
  game/
    regulus_game.dart          FlameGame, fixed-resolution camera (1280x800)
    config.dart                grid + layout constants
    palette.dart               placeholder colours
    components/                game components (playfield, player, enemies…)
assets/
  plates/                      12 zodiac plate images
  shaders/                     fragment shaders (plate shine)
docs/
  design.md                    game design notes
  art-direction.md             visual brief
```

Status: private, work in progress.
