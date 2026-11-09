enum Element { igneous, abyssal, telluric, empty }

/// Elemental weakness wheel: Abyssal→Igneous→Telluric→Void→Abyssal (+30% dmg).
Element elementalWeakness(Element defender) => switch (defender) {
      Element.igneous => Element.abyssal,
      Element.telluric => Element.igneous,
      Element.empty => Element.telluric,
      Element.abyssal => Element.empty,
    };

/// Returns 1.30 if [attacker] is the weakness of [defender], else 1.0.
double elementalWeaknessMultiplier(Element attacker, Element defender) =>
    attacker == elementalWeakness(defender) ? 1.30 : 1.0;
