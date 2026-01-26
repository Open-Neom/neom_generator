## 1.3.0-dev - Architectural Enhancements and Refactoring:
- Huge refactor and improvements.
- Implementation of painter engines and new ways to use generator and chamber.

## 1.3.0-dev - Architectural Enhancements and Refactoring:

Translation Constants Modularization:

GeneratorTranslationConstants has been introduced to centralize all module-specific translation keys related to the frequency generator and Neom Chamber.

This change is part of the broader refactoring of AppTranslationConstants from neom_commons, ensuring that neom_generator now uses its own dedicated translation keys, improving modularity and allowing for flavor-specific overrides at the application level.

Dependency Injection Refinement:

Refactored the consumption of user-related functionalities from direct UserController access to injecting the UserService interface. This adheres to the Dependency Inversion Principle (DIP), enhancing decoupling and testability.

UserService is now obtained via Get.find<UserService>() at the composition root, making neom_generator agnostic to the concrete UserController implementation.

Chamber Management Logic:

The ChamberController has been refined to manage the creation, update, and deletion of "Chambers" (collections of frequency presets), ensuring clear separation of concerns from the main NeomGeneratorController.

ChamberPresetController specifically handles the management of individual frequency presets within a Chamber.

Audio Processing and Recording:

Consolidated the logic for audio recording, pitch detection, and frequency processing within NeomGeneratorController, leveraging flutter_sound and pitch_detector_dart.

Introduced playStopPreview for managing the playback of generated frequencies.

Core Functionality and Features:

Frequency Generation and Parameter Control: Enhanced control over frequency generation (setFrequency) and spatial parameters (setParameterPosition), along with volume adjustment (setVolume).

Voice Frequency Detection: Implemented functionality to detect and display the user's voice frequency, providing real-time biofeedback.

Preset Management: Improved the flow for adding, removing, and updating frequency presets within the Neom Chamber.

Performance and Maintainability Improvements:

Reduced Coupling: neom_generator is now more decoupled from other modules by relying on service interfaces and dedicated translation constants, leading to a cleaner dependency graph.

Enhanced Testability: The shift to interface-based dependency injection makes it significantly easier to write isolated unit tests for NeomGeneratorController and its related components.

Improved Code Clarity: Clearer separation of concerns within the module (e.g., dedicated controllers for Chamber and Chamber Presets) enhances code readability and maintainability.