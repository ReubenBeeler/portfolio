# Render cost

Intel UHD iGPU, 3774x2041, twelve seconds of driven scroll (`?profile`),
reported as the share of 60fps delivered.

**Noise floor: repeat baselines on the same machine span 58-69% yield.** A gap
smaller than that is not a result. Interleave runs and take a median.

## Reliable

| Finding | Evidence |
| --- | --- |
| The card `BackdropFilter` was the single largest cost. | 17 long frames without it against 136 at sigma 5. Far outside the floor. Blur cost does not depend on what is behind it: with the backdrop photo also removed it was still 105. |
| Fill rate is the wall. What costs is pixels shaded per frame, which is viewport pixels times how many times the viewport is filled. | 1.8 Mpx (half window) 94-100%, 2.8 Mpx (dpr 0.6) 71%, 7.7 Mpx (full screen) 64-69%, 7.7 Mpx at 200% zoom 48%. Monotone in pixels at constant fill count, and the zoom run is worse at equal pixels because its content covers twice the area. |
| A quarter of the pixels removes the problem outright. | 100% yield with zero long frames at half width and half height. |

Where a range is given, it is two runs of the same config an hour and a half
apart. The 2.8 Mpx row depends on the dpr override, which is itself unconfirmed
(see below).

## Direction solid, magnitude not

Measured before the scroll was automated, so these carry hand-scroll spread
(one build gave 20 and 42 long frames on two runs of itself).

| Finding | Evidence |
| --- | --- |
| Cubic backdrop resampling was expensive; bilinear is not. | 53 long frames to 11. Cubic is sixteen texture samples per pixel per frame, bilinear runs in the texture unit. The mechanism is not in doubt, the size is: another hand-driven run of the same comparison put cubic at 65 rather than 53. |

## No result, i.e. inside the noise floor or flatly indistinguishable

| Tried | Result |
| --- | --- |
| Removing the backdrop photograph entirely. | 66% against a 69% baseline. Swapping a photo for a black rectangle of the same size does not change how many times the viewport is filled. |
| Dropping the page-level `RepaintBoundary` after hand-over. | 66% against 69%. |
| Dropping the backdrop's own `RepaintBoundary`. | Indistinguishable. |
| Nearest instead of bilinear. | Indistinguishable, and visibly blocky at this ~2x upscale. Not shipped. |
| Rendering at 0.75x the device pixel ratio. | 69% to 75%. Read at the time as cost growing faster than pixel count, but a 6-point gap is inside the floor, and it rests on the unconfirmed dpr override. |

## Untested, worth doing properly

| Open question | Why it is open |
| --- | --- |
| Cross-origin isolation on against off. | Costs an extra document plus worker startup, buys skwasm's raster threads, which is what a raster-bound page wants. The switch existed and no comparison was ever recorded. It was once declared settled in favour of keeping isolation, on no evidence. The most valuable one left. |
| Shadows. | Nine shadow and box-shadow lists across the page, all of them blurs, on a GPU that has visibly failed at blurs. A switch existed; no result was ever recorded. |
| The boot `Scaffold`'s fill. | 65% to 56% with it restored, a single within-noise pair. Shipped transparent on that plus the argument that it is covered everywhere, so this is a shipped change resting on no real evidence. |
| The app `Scaffold`'s fill. | Whether dropping it helps depends on whether Flutter's canvas is opaque, which was never checked. Shipped unchanged, black. |
| Rendering below the device pixel ratio. | dpr 0.6 once scored worse than dpr 0.75, which is impossible if pixel count drives cost. Dart now reports its real ratio and physical size, and the later numbers above look consistent, but nobody re-ran the pair to confirm the override applies. |
