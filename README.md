# wanderlog_alt

An alternative client to see your Wanderlog trips.

## CI/CD Pipeline

This project uses GitHub Actions for Continuous Integration and Continuous Deployment (CI/CD).

### Workflows

- `.github/workflows/flutter-build.yaml`: This workflow runs on all branches except the `master` branch. It builds the Flutter app.
- `.github/workflows/flutter.yml`: This workflow runs only on the `master` branch. It uses the `flutter-build.yaml` workflow as a reusable workflow and includes additional steps to push the app to the Play Store.
