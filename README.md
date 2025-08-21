# portfolio

Hi, there! Enjoy my portfolio, and feel free to reach out about anything!

## TODOs
- Big-Picture:
    - Design a structured view with navigation for bio, resume, social, projects, certifications, etc.
    - Create a bootstrapper loading page and animate-in the dependent components once booted.
- Minor Tweaks:
    - Configure browser tab icon(s) and other similar settings
    - AnimationCrossFade background from theme color to image at boot time to prevent jump from solid color to image (image takes time to load).
    - Add some kind of border around ReubIcon spotlights (inverse primary color?)
    - Set max speed on mouse-proximity animations to avoid spazzy UI if mouse spazzes.
- Goofy Mode (make these icons feel ALIVE):
    - long/indefinite animation times
    - make noise on hover (louder + higher pitch closer to the center)
    - make icon shake or spin with increasing intensity
    - icon bouncing (some options):
        - keep some momentum when ending drag
        - allow icon to leave screen and regenerate it if too far gone
        - make animation super bouncy
        - make path follow planetary-like orbit around default position
        - let the icons collide/bounce off each other instead of z-stacking
        - move back along the same path traced by the mouse when dragging