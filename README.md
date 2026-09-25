# Quick Apply

Android app (Flutter) to apply for jobs by email in one tap: paste the HR/company email (or a whole job post), and the app sends your default application template with your default resume attached.

See [docs/app_requirement.md](docs/app_requirement.md) for the original requirements.

## Features

- **Apply** – paste an email or job post; every address in it is detected. One tap sends the application.
- **Templates** – manage multiple application templates and pick a default. Seeded with a starter template.
- **Resumes** – add PDF/DOC resumes (copied into app storage) and pick a default.
- **Settings** – Gmail address + App Password for background 1-tap sending, and light/dark theme.

## Sending modes

- **Gmail SMTP (1-tap):** with a Gmail App Password configured (Google Account → Security → 2-Step Verification → App passwords), the email is sent directly in the background.
- **Mail app fallback:** without it, the phone's email app opens with recipient, subject, body and resume pre-filled.

## Run

```sh
flutter pub get
flutter run            # emulator or connected device
flutter build apk      # release APK
```
