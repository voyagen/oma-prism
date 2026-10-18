#version 440
// Liquid Glass material. When `backdropOn` is set the wallpaper texture is blurred, saturated and
// refracted at the rim (convex lens + chromatic dispersion) before tint/specular are layered on.
// Rebuild: qsb --qt6 -o shaders/liquidglass.frag.qsb shaders/liquidglass.frag
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;          // item size in px
    float radius;       // corner radius in px
    vec4 tint;          // straight (non-premultiplied) rgb, alpha ignored
    float tintOpacity;  // 0..1
    float darkAppearance; // 1 dark, 0 light
    float lensStrength; // 0..1
    vec2 screenSize;    // wallpaper (screen) size in px; texture covers the whole screen
    vec2 origin;        // this item's top-left in screen px
    float backdropOn;   // 1 when the wallpaper texture is valid
} ubuf;

layout(binding = 1) uniform sampler2D backdrop;

vec3 blurAt(vec2 sp, float radius) {
    // 16-tap Vogel disc in screen px; texture is the whole screen at reduced resolution.
    vec3 acc = vec3(0.0);
    for (int i = 0; i < 16; i++) {
        float fi = float(i) + 0.5;
        float rr = radius * sqrt(fi / 16.0);
        float th = fi * 2.399963;
        vec2 o = rr * vec2(cos(th), sin(th));
        acc += texture(backdrop, clamp((sp + o) / ubuf.screenSize, vec2(0.0), vec2(1.0))).rgb;
    }
    return acc / 16.0;
}

float hash(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float sdRoundRect(vec2 p, vec2 half_, float r) {
    vec2 q = abs(p) - half_ + r;
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
}

void main() {
    vec2 size = ubuf.size;
    vec2 half_ = size * 0.5;
    float r = clamp(ubuf.radius, 0.0, min(half_.x, half_.y));
    vec2 p = qt_TexCoord0 * size - half_;

    float d = sdRoundRect(p, half_, r);      // < 0 inside
    float cover = clamp(0.5 - d, 0.0, 1.0);  // antialiased shape
    if (cover <= 0.0) { fragColor = vec4(0.0); return; }

    // SDF gradient = outward normal
    vec2 e = vec2(0.75, 0.0);
    vec2 n = vec2(sdRoundRect(p + e.xy, half_, r) - sdRoundRect(p - e.xy, half_, r),
                  sdRoundRect(p + e.yx, half_, r) - sdRoundRect(p - e.yx, half_, r));
    n = n / max(length(n), 1e-4);

    float depth = -d;                         // px from edge, inward
    float dark = ubuf.darkAppearance;
    float lens = ubuf.lensStrength;

    float band = clamp(min(12.0, min(half_.x, half_.y)), 1.0, 12.0);
    float t = clamp(depth / band, 0.0, 1.0);
    float edgeFall = pow(1.0 - t, 2.2);       // 1 at edge, 0 inside band
    // Convex lens: bright just inside the edge, darker ring a bit further in.
    float bright = exp(-pow((depth - 1.8) / 2.6, 2.0));
    float ring = exp(-pow((depth - 6.5) / 3.2, 2.0));

    // Light from top-left; y grows downward so L points up-left.
    vec2 L = normalize(vec2(-0.6, -0.8));
    float ndl = dot(n, L);
    float primary = pow(max(ndl, 0.0), 2.0);
    float secondary = pow(max(-ndl, 0.0), 3.0) * 0.45;
    float rim = primary + secondary;
    // Fresnel-ish: rim thickest at the very edge.
    float rimMask = exp(-depth / 1.6);
    float rimWide = exp(-depth / 4.5);

    float hi = dark > 0.5 ? 1.0 : 0.8;
    float lensAmt = lens * (dark > 0.5 ? 1.0 : 0.7);

    vec3 base = ubuf.tint.rgb;
    float a = ubuf.tintOpacity;

    if (ubuf.backdropOn > 0.5) {
        // Convex lens: flat interior, strong smooth displacement inside the rim band
        // (samples are pulled from further in, magnifying and kinking features at the edge).
        float lband = clamp(min(20.0, min(half_.x, half_.y) * 0.95), 1.0, 20.0);
        float lt = clamp(depth / lband, 0.0, 1.0);
        float fall = pow(1.0 - lt, 2.4);
        float mag = fall * 26.0 * lens;
        vec2 sp = ubuf.origin + qt_TexCoord0 * size;
        vec2 disp = -n * mag;
        float blurR = 2.0;
        vec3 col;
        col.r = blurAt(sp + disp * 0.93, blurR).r;
        col.g = blurAt(sp + disp,        blurR).g;
        col.b = blurAt(sp + disp * 1.07, blurR).b;
        float luma = dot(col, vec3(0.2126, 0.7152, 0.0722));
        col = mix(vec3(luma), col, 1.15);                 // near-neutral saturation
        col = col * 1.03 + 0.015;                         // small lift
        // Uniform light veil (independent of the tint slider) + slightly brighter edge area
        // + faint top-to-bottom gradient.
        float vy = clamp((p.y + half_.y) / max(size.y, 1.0), 0.0, 1.0);
        float veil = (dark > 0.5 ? 0.08 : 0.06) + fall * 0.045 * lens + (1.0 - vy) * 0.03;
        col = mix(col, vec3(1.0), veil);
        vec3 body = mix(col, base, a);
        // Hairline specular: strongest on the top edge/corners, fading round the sides, faint at the bottom.
        float top = clamp(-n.y * 0.5 + 0.5, 0.0, 1.0);
        float spec = 0.12 + 0.88 * pow(top, 1.8);
        float hl = exp(-pow((depth - 0.8) / 0.65, 2.0));
        float soft = exp(-pow((depth - 3.2) / 1.8, 2.0));
        body += vec3(1.0) * hl * spec * (dark > 0.5 ? 0.62 : 0.8) * lens;
        body += vec3(1.0) * soft * (0.02 + 0.07 * top) * lens * hi;
        float nz2 = (hash(gl_FragCoord.xy) - 0.5) / 255.0 * 2.0;
        body = clamp(body + nz2, 0.0, 1.0);
        fragColor = vec4(body, 1.0) * cover * ubuf.qt_Opacity;
        return;
    }

    // Interior: tint at tintOpacity so the blurred backdrop shows through.
    vec3 add = vec3(0.0);   // additive light (premultiplied space)
    float shadeA = 0.0;     // extra dark coverage
    add += vec3(1.0) * (bright * 0.10 + rimWide * rim * 0.16) * lensAmt * hi;
    add += vec3(1.0) * rimMask * rim * 0.55 * lens * hi;
    shadeA += ring * 0.16 * lensAmt * (dark > 0.5 ? 1.0 : 0.6);
    // Soft inner glow along the edge, directional.
    add += vec3(1.0) * edgeFall * 0.05 * lens;
    // Hairline border, 1px
    float hair = exp(-pow((depth - 0.5) / 0.6, 2.0));
    add += vec3(1.0) * hair * (dark > 0.5 ? 0.14 : 0.30);
    // Gentle top sheen across the whole surface
    float sheen = clamp(1.0 - (p.y + half_.y) / max(size.y, 1.0), 0.0, 1.0);
    add += vec3(1.0) * sheen * 0.025 * lens * hi;

    float alpha = clamp(a + shadeA * (1.0 - a), 0.0, 1.0);
    vec3 pm = base * a;                      // premultiplied tint
    pm = pm * (1.0 - shadeA);
    float addA = (add.r) * 0.6;              // lit pixels gain a little coverage
    pm += add;
    alpha = clamp(alpha + addA * (1.0 - alpha), 0.0, 1.0);
    pm = min(pm, vec3(alpha));

    // Dither noise
    float nz = (hash(gl_FragCoord.xy) - 0.5) / 255.0 * 2.0;
    pm = max(pm + nz * alpha, 0.0);

    fragColor = vec4(pm, alpha) * cover * ubuf.qt_Opacity;
}
