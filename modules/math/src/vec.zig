// TODO: all vec types: random / noise

pub fn Vec2(T: type) type {
    return @Vector(2, T);
}
// TODO: "don't" care casting
// TODO: constants for vectors (zero / one / directions)
// TODO: equality (maybe with optionals)
// TODO: negate
// TODO: clamp
// TODO: aspect calc
// TODO: sum / diff
// TODO: mul / div by scalar
// TODO: mul / div by vector
// TODO: magnitude / magnitudeSq
// TODO: normalized
// TODO: withMagnitude
// TODO: dot / cross
// TODO: rotated / rotatedAround
// TODO: angle / angleTo / absAngleTo
// TODO: withAngle
// TODO: absed / floored / ceiled / rounded
// TODO: lerped / movedTowards
// TODO: lineInterection (optional return with intersection point)

// TODO: Vec3: research operations

pub fn Col3(T: type) type {
    return @Vector(3, T);
}
// TODO: Col3: research operations 
// TODO: Col4: research operations
// TODO: Col3 <-> Col4 conversions (stripAlpha / withAlpha)
// TODO: Col*: lerp / moveTowards
// TODO: Col3: rgb <-> hsv
// TODO: Col*: color constants

// TODO: Mat3: research operations (if even needed)
// TODO: Mat4: research operations
// TODO: Mat*: add / mul
// TODO: Mat*: projections
// TODO: Mat*: translation / rotation / scale