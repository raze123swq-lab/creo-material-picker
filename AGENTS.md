# Install on Windows

When asked to install, run these steps from the repository root:

1. Run `powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File .\Check.ps1` and inspect its exit code and JSON. If no installation is detected, locate Creo Parametric 12.x on disk before proceeding. Resolve multiple installations with the user. If CreoOpen is true, wait for the user to save and exit; do not kill Creo.
2. Run `powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File .\Install.ps1 -CreoRoot "<detected root>"`. Stop on failure. This installs for the current Windows user.
3. Verify the desktop shortcut's target script and sibling index.csv. Verify every indexed file exists and keys are unique. Launch the shortcut and verify the window opens. Report actual counts. Do not change a user's model for verification.
