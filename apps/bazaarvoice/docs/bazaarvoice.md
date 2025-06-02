---
title: Bazaarvoice
layout: home
---

# Bazaarvoice

This app provides a lightweight, out-of-process solution to manage Bazaarvoice integration settings for Adobe Commerce. Configuration is set at install time via Adobe Exchange, and the app exposes a read-only endpoint to retrieve these settings for use in your Commerce instance.

## App Functionality

- **Configuration**: Set via Adobe Exchange at install time, including:
  - Enable/disable Bazaarvoice extension
  - Environment (staging/production)
  - Client name
  - Product families, deployment zone, locale, SEO key, BV Pixel, debug mode
  - SFTP details for product feeds
- **Action**: The `bazaarvoice-config` action (GET-only) retrieves these settings from environment variables and returns them as JSON.
- **UI**: An optional front-end (under `commerce-backend-ui-1`) can display this config if implemented.

## Integration with Adobe Commerce

- Use the `bazaarvoice-config` endpoint (`/api/v1/web/aio-commerce-bazaarvoice-app/bazaarvoice-config`) in a custom Commerce module to access settings.
- Deploy the UI (if built) in the Admin Panel via the `commerce-backend-ui-1` extension.
