import 'package:flutter/widgets.dart';

/// True while running under `flutter test`.
///
/// The widget-test binding (`AutomatedTestWidgetsFlutterBinding`) cannot
/// initialize GPU fragment programs nor advance infinite animations, so every
/// ambient cinematic layer checks this flag and renders a single static frame
/// instead. Production (device, web, profile) always animates.
bool get isWidgetTestEnvironment =>
    WidgetsBinding.instance.runtimeType.toString().contains('Test');

/// Test-safe helper: how many ambient particles a scene should spawn.
int ambientParticleCount(int production, {int test = 0}) =>
    isWidgetTestEnvironment ? test : production;
