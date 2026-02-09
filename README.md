# neom_generator

Neom Generator - Frequency Generation and Binaural Beat Engine for Open Neom.

neom_generator is a core module within the Open Neom ecosystem, dedicated to the generation and manipulation of frequencies and audio patterns. It provides the foundational tools for creating personalized sound experiences, enabling users to interact with the "Neom Chamber" for guided meditation, conscious well-being, and biofeedback applications.

This module is designed for mobile app integration with a future vision for wearables and IoT devices, aligning with the broader Tecnozenism philosophy of integrating technology and human consciousness.

## Features & Responsibilities

### Frequency Generation
- Core logic for generating specific audio frequencies
- Binaural beat synthesis with configurable differential
- Isochronic tone generation
- Real-time parameter modulation

### Audio Visualization
- **Oscilloscope View**: Real-time waveform display
- **Lissajous Patterns**: Phase relationship visualization
- **Flocking Animation**: Particle-based visual feedback
- **Breathing Guide**: Animated breath synchronization

### Neom Chamber Management
- Create and manage frequency preset collections
- Privacy options (public/private chambers)
- Binaural configuration presets
- Session recording and export

### Control Panels
- **Spatial Control**: 3D audio positioning (X, Y, Z axes)
- **Breath Control**: Breathing rate synchronization
- **Neuro State Control**: EEG band targeting (Delta, Theta, Alpha, Beta, Gamma)
- **Modulation Control**: Amplitude and frequency modulation
- **Visual Mode Control**: Scientific vs artistic display modes

### Voice Frequency Detection
- Microphone input analysis
- Real-time pitch detection
- Biofeedback visualization

## Architecture

```
lib/
├── engine/
│   ├── neom_audio_engine.dart
│   ├── neom_frequency_painter_engine.dart
│   └── neom_sine_engine.dart
├── ui/
│   ├── neom_generator_controller.dart
│   ├── neom_generator_page.dart
│   ├── breathing/
│   │   └── neom_breathing_fullscreen_page.dart
│   ├── chamber/
│   │   ├── chamber_controller.dart
│   │   └── chamber_page.dart
│   ├── flocking/
│   │   └── neom_flocking_fullscreen_page.dart
│   ├── oscilloscope/
│   │   ├── neom_oscilloscope_fullscreen_page.dart
│   │   └── neom_oscilloscope_fullscreen_painter.dart
│   ├── painters/
│   │   ├── frequency_painter.dart
│   │   ├── lissajous_painter.dart
│   │   ├── neom_binaural_beat_painter.dart
│   │   ├── neom_breathing_painter.dart
│   │   ├── neom_flocking_painter.dart
│   │   └── oscilloscope_painter.dart
│   ├── panels/
│   │   ├── neom_breath_control_panel.dart
│   │   ├── neom_modulation_control_panel.dart
│   │   ├── neom_neuro_state_control_panel.dart
│   │   ├── neom_spatial_control_panel.dart
│   │   └── neom_visual_mode_control_panel.dart
│   └── widgets/
│       ├── generator_widgets.dart
│       └── session_time_meter.dart
├── utils/
│   ├── constants/
│   │   ├── generator_translation_constants.dart
│   │   ├── neom_generator_constants.dart
│   │   └── neom_slider_constants.dart
│   └── enums/
│       ├── eeg_band.dart
│       ├── neom_frequency_target.dart
│       └── neom_numeric_target.dart
└── neom_generator.dart
```

## Dependencies

```yaml
dependencies:
  neom_core: ^2.0.0           # Core services and models
  neom_commons: ^2.0.0        # Shared UI components
  sint: ^1.0.0                # State management (SINT framework)
  flutter_soloud: ^3.1.6      # High-performance audio engine
  sleek_circular_slider: ^2.0.1  # Custom circular sliders
  font_awesome_flutter: ^10.8.0  # Icon set
```

## Usage

### Launching the Generator Page

```dart
import 'package:neom_generator/ui/neom_generator_page.dart';

// Navigate to generator
Sint.toNamed(AppRouteConstants.generator);

// Or embed directly
NeomGeneratorPage(showAppBar: true)
```

### Using the Generator Controller

```dart
import 'package:neom_generator/ui/neom_generator_controller.dart';

final controller = Sint.find<NeomGeneratorController>();

// Set frequency
controller.setFrequency(432.0);

// Set binaural beat differential
controller.setBinauralBeat(10.0); // 10 Hz for Alpha state

// Play/Stop
controller.playStopPreview();
```

### Creating a Chamber Preset

```dart
import 'package:neom_generator/ui/chamber/chamber_controller.dart';

final chamberController = Sint.find<ChamberController>();

// Create new chamber
await chamberController.createChamber(
  name: "Morning Meditation",
  baseFrequency: 432.0,
  binauralBeat: 7.83, // Schumann resonance
  isPublic: false,
);
```

## EEG Bands and Frequencies

| Band | Frequency | State |
|------|-----------|-------|
| Delta | 0.5 - 4 Hz | Deep sleep, healing |
| Theta | 4 - 8 Hz | Meditation, creativity |
| Alpha | 8 - 12 Hz | Relaxation, calm focus |
| Beta | 12 - 30 Hz | Alert, active thinking |
| Gamma | 30+ Hz | Peak performance, insight |

## ROADMAP 2026

### Q1 2026 - Advanced Audio Engine
- [ ] Multi-voice synthesis (up to 8 simultaneous frequencies)
- [ ] Custom waveform generation (sine, triangle, square, sawtooth)
- [ ] Harmonic overtone series
- [ ] ADSR envelope control

### Q2 2026 - Biofeedback Integration
- [ ] Heart rate variability (HRV) sync
- [ ] Breathing sensor integration
- [ ] EEG headband support (Muse, OpenBCI)
- [ ] Real-time coherence feedback

### Q3 2026 - Session Management
- [ ] Guided session templates
- [ ] Progress tracking and analytics
- [ ] Session export (audio files)
- [ ] Cloud sync for presets

### Q4 2026 - Social Features
- [ ] Public chamber sharing
- [ ] Community presets
- [ ] Collaborative sessions
- [ ] Expert-curated programs

## State Management

neom_generator uses the SINT framework (GetX replacement) for:
- Reactive audio parameter binding
- Real-time visual state updates
- Controller lifecycle management
- Route-based dependency injection

## Contributing

We welcome contributions! If you're interested in audio processing, visualization, or meditation technology, your help can enhance the Neom Generator experience.

## License

This project is licensed under the Apache License, Version 2.0, January 2004. See the LICENSE file for details.
