# Changelog

All notable changes to neom_generator will be documented in this file.

## [2.0.0] - 2025-02-09

### Changed
- Replaced deprecated `withOpacity()` with `withValues(alpha:)` across all files (100+ instances)
- Replaced deprecated `WillPopScope` with `PopScope` and `onPopInvokedWithResult`
- Replaced deprecated `Radio` groupValue/onChanged with `SegmentedButton`
- Added `notifyVisualUpdate()` public method to NeomFrequencyPainterEngine
- README.md with comprehensive documentation and ROADMAP 2026

### Fixed
- Protected member access warning for `notifyListeners()` in controller
- Import ordering compliance with flutter_lints ^6.0.0

### Improved
- Code compliance with latest Flutter/Dart deprecation guidelines
- Clean Architecture adherence

## [1.5.0] - 2025-01-20

### Added
- Oscilloscope fullscreen visualization
- Flocking animation with boid simulation
- Breathing guide fullscreen mode
- Lissajous pattern painter
- Session time meter widget

### Changed
- Enhanced painter engine with smoothing profiles
- Improved binaural beat visualization

## [1.4.0] - 2025-01-01

### Added
- Control panels: Spatial, Breath, Neuro State, Modulation, Visual Mode
- EEG band detection and color coding
- Hemispheric coherence meter
- Visual amplitude controls

### Changed
- Migrated from GetX to SINT framework
- Updated SDK constraint to >=3.8.0 <4.0.0

## [1.3.0-dev] - 2024-11-01

### Added
- Painter engines for visual feedback
- Chamber management improvements
- Voice frequency detection

### Changed
- Refactored translation constants modularization
- Dependency injection refinement (DIP compliance)
- Consolidated audio processing logic

## [1.2.0] - 2024-08-15

### Added
- ChamberController for preset collections
- ChamberPresetController for individual presets
- Privacy options for chambers

### Changed
- Enhanced frequency generation controls
- Improved spatial parameter positioning

## [1.0.0] - 2024-05-01

### Added
- Initial release
- Core frequency generation engine
- Neom Chamber management
- Basic UI components
- Integration with neom_core and neom_commons
