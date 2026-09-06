# Practical Assignment 2: CI/CD using Bicep and GitHub Actions

This project implements **Question 2** from the supplied assignment. It assumes GitHub Actions is acceptable: the question does not prescribe a CI/CD tool. Bicep provisions infrastructure; GitHub Actions orchestrates build, tests and deployment. This is a student demonstration, not a production hosting design.

## What you are building

| Requirement | Implementation |
|---|---|
| Source code integration | GitHub repository, pull requests and pushes to main |
| Automated build | Node syntax check, creation of dist, ZIP packaging |
| Automated testing | HTTP tests for health, home page and missing route |
| Continuous integration | Build and tests on pull requests and main pushes |
| Infrastructure as Code | Bicep App Service plan, two web apps, deployment identity and access |
| Continuous deployment | Successful main builds deploy automatically |
| Delivery stages | Build/test, infrastructure, development deployment/check, production deployment/check |
| Deployment automation | Same ZIP promoted to both apps; health checks verify commit SHA |

Both demo apps share one Linux F1 Free App Service plan. They are separate apps, not deployment slots. Free hosting has quotas, can sleep and has no production SLA. No database, VM, paid plan, Key Vault or monitoring workspace is required. Do not change F1 to B1 casually: paid plans consume credit even when their web apps are stopped. GitHub Actions usage has separate account allowances; check your GitHub billing settings, particularly for private repositories.

## Files

- `infra/main.bicep`: Free hosting plan, dev/prod apps, runtime and outputs.
- `infra/bootstrap.bicep`: one-time GitHub identity, main-branch federation and Contributor access scoped to this assignment resource group.
- `.github/workflows/cicd.yml`: full CI/CD workflow.
- `app/`: dependency-free Node.js application, tests and build script.
- `scripts/smoke.py`: checks deployed environment and exact commit version.

The bootstrap identity has Contributor access because the pipeline manages infrastructure. It has no subscription-wide assignment and cannot grant roles. Bootstrap is run by you, not by the pipeline. Keep this resource group dedicated to the assignment.

## 1. Prepare tools and repository

On a Mac with Homebrew installed:

```bash
brew install azure-cli node@22 git
export PATH="$(brew --prefix node@22)/bin:$PATH"
az bicep install
az version
az bicep version
node --version
```

Install the Microsoft Bicep extension in VS Code. Extract this ZIP and open the `assignment-2-bicep` folder. The hidden `.github` directory must be included when uploading to GitHub.

Create an empty GitHub repository called `contoso-assignment-2`. Do not add a README or license during creation. The guide uses a main branch. No Azure DevOps account is needed.

## 2. Sign in and choose your subscription

Run from the extracted project root. Replace all placeholders before running.

```bash
az login
az account list --output table
az account set --subscription 'YOUR-STUDENT-SUBSCRIPTION-ID'
az account show --query '{name:name,id:id,state:state}' --output table

PREFIX='your-srn-yourfirstname'
RG="$PREFIX"
LOCATION='southeastasia'
REPO='YOUR-GITHUB-USERNAME/contoso-assignment-2'
```

Use your actual **lowercase SRN-firstname** for PREFIX, 3–35 characters, containing only letters, digits and hyphens, starting/ending with a letter or digit. Example format only: `pesxxxxxxxx-apurva`. The resource group uses that exact name; related resources add purpose suffixes and the web apps add a stable uniqueness suffix. If your faculty requires a different naming interpretation, adapt it before deployment.

`LOCATION` is an example, not a guarantee for your student subscription. In Azure Portal, open **Policy > Assignments** at your subscription scope and inspect any allowed-location policies. Choose an allowed region that also supports Linux F1. This CLI list shows service support, not your subscription policy permission:

```bash
az appservice list-locations --sku F1 --linux-workers-enabled --output table
az webapp list-runtimes --os linux --output table
```

Check that Node 22 LTS is listed. If unavailable, select a supported Node LTS consistently in main.bicep, package.json and the workflow, then refresh the lockfile with npm install --package-lock-only.

Register providers and create a dedicated group:

```bash
az provider register --namespace Microsoft.Web --wait
az provider register --namespace Microsoft.ManagedIdentity --wait
az group create --name "$RG" --location "$LOCATION"
```

Resource group creation here is the CLI setup step. Application infrastructure and the authentication identity are defined in Bicep.

## 3. Run the application locally

```bash
cd app
npm ci
npm test
npm run build
npm start
```

Open http://localhost:8080 and http://localhost:8080/health. Stop with Ctrl+C, then return to the project root:

```bash
cd ..
```

There are no external npm dependencies. The build packages the server and generates release metadata; plain JavaScript does not require transpilation. CI uses the commit SHA as the version.

## 4. Validate and deploy the Bicep infrastructure

```bash
az bicep build --file infra/main.bicep
az bicep build --file infra/bootstrap.bicep

az deployment group validate --resource-group "$RG" \
  --template-file infra/main.bicep --parameters namePrefix="$PREFIX"

az deployment group what-if --resource-group "$RG" \
  --template-file infra/main.bicep --parameters namePrefix="$PREFIX"

az deployment group create --name infrastructure --resource-group "$RG" \
  --template-file infra/main.bicep --parameters namePrefix="$PREFIX"

az deployment group show --resource-group "$RG" --name infrastructure \
  --query properties.outputs --output json
```

Expect an App Service plan and two web apps. At this point your application code has not been deployed yet. Bicep creates the hosting resources; the pipeline deploys the ZIP later. Inspect the plan in Azure Portal and verify **F1 / Free**.

## 5. Bootstrap GitHub authentication once

You need permission to create resources and grant roles at the assignment resource group (for example, Owner). Contributor alone cannot create role assignments. If your university restricts this, ask its Azure administrator to run the bootstrap or grant the necessary scoped access.

```bash
az deployment group create --name github-auth --resource-group "$RG" \
  --template-file infra/bootstrap.bicep \
  --parameters namePrefix="$PREFIX" githubRepository="$REPO"

az deployment group show --resource-group "$RG" --name github-auth \
  --query properties.outputs --output json
```

Copy the output IDs into GitHub **Settings > Secrets and variables > Actions > Secrets**:

| GitHub secret | Bootstrap output |
|---|---|
| AZURE_CLIENT_ID | clientId.value |
| AZURE_TENANT_ID | tenantId.value |
| AZURE_SUBSCRIPTION_ID | subscriptionId.value |

On the **Variables** tab add:

| GitHub variable | Value |
|---|---|
| AZURE_RESOURCE_GROUP | Exact value of RG |
| NAME_PREFIX | Exact value of PREFIX |

No client secret or publish profile is needed. Allow a few minutes for identity permissions to propagate. The trust is restricted to the exact repository and main branch. Do not add a GitHub `environment:` property to jobs without also updating the federated subject; environment-based tokens use a different subject.

## 6. Push the project and watch the automatic deployment

From the project root, after configuring GitHub secrets and variables:

```bash
git init
git branch -M main
git add .
git commit -m 'Implement assignment 2 CI/CD with Bicep'
git remote add origin "https://github.com/$REPO.git"
git push -u origin main
```

Authenticate to GitHub using its supported browser/token flow when prompted. Never put a token in source code or a remote URL.

Open **GitHub > Actions > Contoso CI-CD**. You should see these sequential jobs:

1. `build_test`: tests, builds, Bicep syntax validation and artifact upload.
2. `infrastructure`: signs in using OIDC, previews and applies the infrastructure.
3. `deploy_dev`: deploys ZIP and verifies the development release.
4. `deploy_prod`: runs only after development passes, deploys the same ZIP and verifies production.

Pull requests execute CI only. Failed CI prevents downstream deployments; failed development verification prevents production promotion. Infrastructure changes affect both apps before application rollout. The workflow does not automatically roll back a failed deployment. Production here is a demo stage, with no manual approval, so this demonstrates continuous deployment.

## 7. Verify Azure and demonstrate a second release

```bash
az resource list --resource-group "$RG" --output table
az appservice plan list --resource-group "$RG" \
  --query '[].{name:name,sku:sku.name,tier:sku.tier}' --output table

DEV_URL=$(az deployment group show --resource-group "$RG" --name infrastructure \
  --query properties.outputs.devUrl.value --output tsv)
PROD_URL=$(az deployment group show --resource-group "$RG" --name infrastructure \
  --query properties.outputs.prodUrl.value --output tsv)

curl --fail "$DEV_URL/health"
curl --fail "$PROD_URL/health"
git rev-parse HEAD
```

The health responses must show the correct environment and the commit SHA. Browse both home pages. Change the visible sentence in `app/server.js` (keep the company name so the test remains valid), then run:

```bash
git add app/server.js
git commit -m 'Demonstrate automatic second release'
git push
```

Watch the pipeline run without any manual Azure code deployment. Refresh the website and health endpoint to show the updated page and new SHA.

For a negative test, create a temporary branch, change the expected company name in the unit test to an incorrect value, push it and open a pull request. Capture the failed CI check. Correct the test and capture the successful run. Do not merge the intentionally failing version. Configure main branch protection requiring CI if available for your repository; the workflow itself does not prevent someone from merging a failing PR.

## 8. Single-PDF submission evidence

The uploaded assignment requires **executed commands with output screenshots of Azure resources** in a single PDF. This project is the implementation kit, not a completed evidence submission. Capture your own real results; do not present expected output as executed output.

Suggested report sequence:

1. Cover: assignment 2, name, SRN, course and date.
2. Aim and requirement-to-implementation table from this guide.
3. Architecture: GitHub source, build/tests, Bicep infrastructure, dev verification, prod verification.
4. Tool-version and selected subscription command screenshots.
5. Bicep code, successful validation and what-if output.
6. Successful deployment output, resource group resources and F1 plan screenshot.
7. Managed identity federation and scoped role assignment (never show credentials).
8. GitHub workflow code and secret/variable **names**, not values.
9. All four successful pipeline jobs and build/test logs.
10. Dev/prod pages and health JSON showing environment and matching commit SHA.
11. Second commit, second automatic pipeline run and updated live application.
12. Optional failed test evidence showing deployment prevention.
13. Conclusion stating what you actually verified and any limitations.

Paste screenshots into Word or Google Docs with brief captions and export as a single PDF. Keep commands legible. Do not include sign-in tokens, passwords or credential files.

## Troubleshooting

| Symptom | Next action |
|---|---|
| RequestDisallowedByAzure / policy denial | Inspect the denied resource and assigned allowed regions; use an allowed region supporting Linux F1. Do not assume RG creation proves service permission. |
| F1 quota/capacity error | Inspect existing Free plans, choose an allowed supported region or ask support. Do not silently upgrade to a paid SKU. |
| AuthorizationFailed during bootstrap | Check role-assignment permission; university admin may need to perform this step. |
| No matching federated identity | Check exact owner/repo casing, main branch, issuer and subject. Re-run bootstrap with the correct repo value. |
| Pipeline Forbidden after bootstrap | Allow RBAC propagation, then rerun; verify identity client ID and resource group scope. |
| Application error / smoke timeout | Inspect App Service Log stream; confirm Node runtime, startup command node server.js, ZIP root contents and F1 quota. |
| Deployment works but page unchanged | Check /health version against commit SHA; the smoke test deliberately rejects an old running release. |
| Region change after initial deployment | App Service location cannot simply be changed in place. For an empty disposable demo, clean up and recreate the dedicated group in the new allowed region. |

## Cleanup after recording evidence

Keep the demo until faculty evaluation is complete. When finished, disable the GitHub workflow first so another push cannot attempt a redeployment. The following command deletes **everything in the named resource group**, including both apps and the identity. Verify the resource list before confirming:

```bash
az resource list --resource-group "$RG" --output table
az group delete --name "$RG"
```

Remove the three Azure GitHub secrets and two variables when no longer needed.

## Verification status of this supplied project

Application HTTP tests and build passed locally using Node 24; CI is configured to repeat them on Node 22. Azure CLI/Bicep were unavailable in the authoring environment, so Bicep compilation, Azure validation, OIDC login and live deployment have not been executed here. Run the listed validation steps before deployment. Region permission, quotas and live runtime availability are subscription-specific.

## Official references

- Azure App Service GitHub Actions and OIDC: https://learn.microsoft.com/en-us/azure/app-service/deploy-github-actions
- App Service plan behavior and Free pricing tier: https://learn.microsoft.com/en-us/azure/app-service/overview-hosting-plans
- Node runtime configuration: https://learn.microsoft.com/en-us/azure/app-service/configure-language-nodejs
- Bicep installation: https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/install
- Bicep federated identity resource: https://learn.microsoft.com/en-us/azure/templates/microsoft.managedidentity/userassignedidentities/federatedidentitycredentials
- Azure for Students offer: https://azure.microsoft.com/en-us/free/students
