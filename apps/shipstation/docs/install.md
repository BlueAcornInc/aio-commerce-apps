---
title: Installation
layout: home
parent: Shipstation
---

# Installation Guide

Reviews and other concerns are presented to customers through blocks in Adobe Commerce Storefront. Some configurations can be stored in the content repo, or in the Adobe Commerce Administrative backoffice where things like private credentials can be stored. The blocks are designed to be paired with the app to provide complete functionality.


## Installing the App

Find the app in the Adobe Exchange, and Aquire it.

![Aquire the App](img/exchange-acquired.png)

Then we need to manage it, and create an environment to deploy it to. This environment is like an Adobe Developer App Builder Environment, that you will need to link to your instance (see below!):

![Manage the App](img/exchange-manage.png)

Make sure to use the project it's deployed to:

![App Environment](img/exchange-app-envs.png)

### App Variables

| Variable Name         | Value                         |
|-----------------------|------------------------------|
| `COMMERCE_ENDPOINT`   | `https://<your-production-storefront-url>/` |


## Setting up The Out-Of-Process Shipping Method

Customers will need to create the out-of-process shipping method in order to complete the installation. This can be done through an onboarding script but it may be required to create it manually. 

This can be done by leveraging the Checkout Integration Starter Kit. Please ensure the following method is registered on the target storefront:

Replace [shipping-carriers.yaml](https://github.com/adobe/commerce-checkout-starter-kit/blob/main/shipping-carriers.yaml) with the following and post the shipping method.

```yaml
shipping_carriers:
  - carrier:
      code: "ShipStation"
      title: "ShipStation Shipping"
      stores:
        - default
      countries:
        - US
      active: true
      sort_order: 10
      tracking_available: true
      shipping_labels_available: true

```


## PaaS App Setup

This guide will walk a merchant or a developer through how to set up this project with an Adobe Commerce SaaS Workspace. It assumes you have nothing but the following entitlements from Adobe:

### Pre-Reqs

* Adobe Developer App Builder 
* Access to a working Adobe Commerce as a Cloud Service (SaaS) tenant
* Local evironment running linux or compatible (i.e. MacOS or Windows with WCL2)
    * This repo contains a devcontainer suitable for running the solution, which requires a compatible IDE like Visual Studio Code and an OCI Runtime like Docker or Podman

### Setup SaaS and Storefront

If you haven't already, we need to prepare the project and workspaces within our Adobe App Builder organization, as well as the code repos that represent Adobe Commerce Storefront and any additional public apps you may need to use.

`aio commerce init` will create a few repos for you in github, so you must be authenticated with github. the `gh` tool can help with this.

```bash
$ gh auth login 
$ aio commerce init
```

### Create an Integration in Adobe Commerce Admin

- This step allows your App Builder application to authenticate and communicate with your Adobe Commerce backend.

- In the Adobe Commerce Admin panel:

   - Navigate to:  
     `System > Extensions > Integrations`

     - Click **Add New Integration**

     - Fill in the following values:
        - **Name**: e.g. `Stripe App Builder Integration`
        - Leave other fields blank unless required by your organization

     - Under the **API** tab, click **Select All** to grant all permissions, or configure scopes as needed

     - Save the integration and then **activate** it

     - You will be shown the following credentials:
        - **Consumer Key**
        - **Consumer Secret**
        - **Access Token**
        - **Access Token Secret**

- Remove the commented out Option 1 fields and update these to your `.env` file:

```env
  COMMERCE_CONSUMER_KEY=your-consumer-key
  COMMERCE_CONSUMER_SECRET=your-consumer-secret
  COMMERCE_ACCESS_TOKEN=your-access-token
  COMMERCE_ACCESS_TOKEN_SECRET=your-access-token-secret
```

This will allow the app to fetch commerce data in future updates.

### Register App to Commerce Instance

This app has an Administrative compliment, which requires the Adobe IMS and Admin UI SDK to be configured. 

#### Setting up IMS

Behind the scenes, there is an app repository this gets registered with. It is exposed through IMS, so be sure to have your instances configured with IMS and in the same organization as your users and apps.

* [Setup IMS for Adobe Commerce](https://experienceleague.adobe.com/en/docs/commerce-admin/start/admin/ims/adobe-ims-config)

#### Setting up Admin UI SDK

Stores > Configuration > Adobe Services > Admin UI SDK and configure it to suit your needs.

#### Running Locally

![Running Admin UI SDK Locally](img/admin-ui-sdk-setup.png)

Once setup, click __Refresh Registrations__ to bring in the app. This will expose the App in the _Apps_ section of the Main Admin Menu.

