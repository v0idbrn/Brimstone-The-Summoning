import '../value_objects/orb_level.dart';
import '../value_objects/element.dart';

class FuseOrbs {
  OrbLevel fuse(OrbLevel a, OrbLevel b, Element ea, Element eb) {
    if (ea != eb) return a;
    if (a == OrbLevel.one && b == OrbLevel.one) return OrbLevel.two;
    if (a == OrbLevel.two && b == OrbLevel.two) return OrbLevel.three;
    return a;
  }
}
