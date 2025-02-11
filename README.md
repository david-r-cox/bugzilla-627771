# Firefox Gradient Dithering Fix

This repository contains a Nix flake and patches that aim to fix a determinism issue with gradient dithering in Firefox's WebRender component. The fix addresses [Bug 627771](https://bugzilla.mozilla.org/show_bug.cgi?id=627771) which has been open for 14 years.

### Status

Not Yet Fixed

## Problem Description

When rendering gradients with WebRender's texture atlas system, the dithering pattern is non-deterministic between reference and actual output. This occurs because:

1. The dither pattern is based on screen coordinates (`gl_FragCoord`)
2. When textures are placed in an atlas, their screen position changes
3. This causes the dither pattern to shift based on screen position rather than staying consistent with the texture

This inconsistency leads to reference comparison failures and makes gradient rendering non-deterministic.

## Solution

The fix implements the following changes:

1. Adds a `uTextureOffset` uniform to gradient shaders to receive the texture atlas offset
2. Modifies the gradient shader to use `gl_FragCoord.xy + uTextureOffset.xy` for dither pattern positioning
3. Updates the renderer to pass texture offset from `CacheTextureId` to shader for each gradient type
4. Sets the uniform after shader binding to ensure proper state

These changes make the dither pattern position relative to the texture's position in the atlas rather than screen position, ensuring deterministic output for reference comparisons.

## Implementation Details

### Files Modified

- `gradient.glsl`: Added uniform variable and modified dither calculation
- `mod.rs`: Updated renderer code to pass texture offsets to shader
- `flake.nix`: Nix flake configuration for building Firefox with the patches

### Key Changes

1. In `gradient.glsl`:
```glsl
uniform vec4 uTextureOffset;

vec4 dither(vec4 color) {
    ivec2 pos = ivec2(gl_FragCoord.xy + uTextureOffset.xy) & ivec2(matrix_mask);
    // ... rest of dither implementation
}
```

2. In `mod.rs`:
```rust
// Get texture from cache and set offset uniform
let texture = &self.texture_resolver.texture_cache_map[&texture_id].texture;
let uniform_offset = texture.get_offset();
let texture_offset = [
    uniform_offset.x as f32,
    uniform_offset.y as f32,
    0.0,
    0.0,
];
self.device.set_uniform_4fv("uTextureOffset", &texture_offset);
```

## Building

This project uses Nix flakes to build Firefox with the gradient dithering patches. To build:

1. Ensure you have Nix installed with flakes enabled
2. Run:
```bash
nix build .#firefox
```

The build uses ccache for faster rebuilds and LLVM/Clang as the compiler.

## Testing

To verify the fix:
1. Build and run the patched Firefox
2. Navigate to the [test page](https://kzmgyv68y4zjaij3dco9.lite.vusercontent.net/)
3. Compare the rendered output with a different browser
4. The dither patterns should be consistent regardless of texture atlas position

## License

All Nix code is under the MIT license. All patches are subject to the Mozilla Public License v2.0.
