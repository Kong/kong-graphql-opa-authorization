# GraphQL Authorization Pattern with Konnect, OPA and OIDC

<p align="center">
  <img src="https://konghq.com/wp-content/uploads/2018/08/kong-combination-mark-color-256px.png" /></div>
</p>

The objective of this tutorial is to understand how to implement authentication and authorization for GraphQL APIs using OIDC and OPA with Konnect.

The solution should solve for the Authentication and Authorization concerns at the gateway layer. First, users should be authenticated, and if authenticated, then the user’s fine-grain permissions should be evaluated to determine if user has permission to run the incoming graphql request (whether the request is nested, or using query variables).

<p align="center">
    <img src="img/arch/reference_arch.png"/></div>
</p>

## Table of Contents

<!-- @import "[TOC]" {cmd="toc" depthFrom=2 depthTo=6 orderedList=true} -->

<!-- code_chunk_output -->

* [Prerequisites](#prerequisites)
* [Environment Setup](#environment-setup)
  * [Keycloak and OPA Docker](#keycloak-and-opa---docker-containers)
  * [Konnect Runtime Instance Docker](#konnect-dp---docker-container)
  * [Keyclok Configuration](#keycloak-configuration)
  * [OPA Configuration](#opa-engine-configuration)
  * [Konnect Configuration](#konnect-configuration)
  * [Insomnia Configuration](#insomnia-configuration)
* [Tutorial](#tutorial)
  * [Step 1 - OIDC Plugin](#step-1---oidc-plugin)
  * [Step 2 - OPA Plugin](#step-2---opa-plugin)
  * [Step 3 - Testing OPA Behavior - kong_id](#step-3---testing-opa-behavior)
  * [Step 4 - Testing OPA Behavior - customer_id](#step-4---testing-opa-behavior)
* [Clean up](#cleaup)
* [Summary](#summary)

<!-- /code_chunk_output -->

## Tutorial Overview

We’re protecting the demo Frankfurter GraphQL API, an exchange rate API by StepZen.

In our scenario, we have 2 types of users, kong users and customers users set up in Keycloak.

* The kong users should have special privileges. These are the only users allowed to hit the frankfurter_convertedAmount query.
  * Plus additional restrictions to demonstrate constant and query variable validation.
* Anyone with a valid JWT (kong and customers) should be able to see the frankfurter_currency_list.

The matrix of permissions is diagrammed below.


<p align="center">
    <img src="img/arch/overview.png" width=1000/></div>
</p>

## Prerequisites

The prequisites for the tutorial:

1. [Konnect Plus Account](https://konghq.com/products/kong-konnect/register) - for use of OIDC and OPA Plugin
2. [Konnect Personal Access Token](https://docs.konghq.com/konnect/runtime-manager/runtime-groups/declarative-config/#generate-a-personal-access-token)
3. Docker and docker compose
4. Insomnia Desktop Application

## Environment Setup

First, clone this repository:

```console
https://github.com/Kong/kong-stepzen-opa-authorization.git
```

### Keycloak and OPA - Docker Containers

Docker compose file will create three components: kong-net docker network, opa container, and keycloak container.

```console
docker compose up
```

### Konnect DP - Docker Container

Login into Konnect at `https://cloud.konghq.com/`

**Create the Konnect Runtime instance**

In the `default` runtime group create a new runtime instance --> Select Linux(Docker) --> Select `Generate script`

Copy the script and before running in the terminal we need to update add the `--network=kong-net` to the command. An example below:

```console
docker run -d \
--network=kong-net \ <-- add this arg to your command 
-e "KONG_ROLE=data_plane" \
-e "KONG_DATABASE=off" \
-e "KONG_VITALS=off" \
...
-e "KONG_KONNECT_MODE=on" \
-p 8000:8000 \
-p 8443:8443 \
kong/kong-gateway:3.1.1.3
```

You should see the gateway successfully connected under `Runtime Instances` menu.

### Keycloak Configuration

You will create two clients in Keycloak, `kong_id` and `customer_id` that will be setup with `client_credentials` OAuth flow.

Login to keycloak:

* url - `http:localhost:8080/admin`
* username - `admin`
* password - `admin`

#### Create Realm

In the drop down menu on the left nav bar where it says `master`:

* open the drop down menu
* select `Create Realm`
* In the Create realm menu
  * fill in Realm name  `kong`
  * select `Create` Button

#### Create Clients

Here we will will step through how to make the `kong_id` client. This process needs to be repeated to create the `customer_id` client as well.

1. In the left-panel the kong realm should be selected --> Navigate to clients --> select `Create client` --> fill in `Client ID` with `kong_id`

2. Select `Next` at the bottom of the menu --> Toggle on `client authentication`, and for Authentication Flow toggle `Standard Flow` and `Service account roles` --> Press `Save`

3. Navigate to Credentials Tab and copy the client secret. Save the client secret for later.

4. Repeat this process to create the `customer_id` client.

### OPA Engine Configuration

The graphql policy needs to be published to the OPA engine.

Execute the http request below to put the policy on the local opa server.

```console
curl -XPUT http://localhost:8181/v1/policies/graphql --data-binary @opa/graphql.rego
```

### Konnect Configuration

The last setup task we will do is use to `decK` to help expedite the setup of gateway. The `kong.yaml` file has the configuration that we are going to sync up to Konnect.

The following configuration will be synced up:

* a gateway service pointing to a graphQL service
* route
* OIDC plugin - on the route - configure to the local keycloak docker instance
* OPA plugin - on the route - configure to the local OPA docker instance

To start, both the plugins will be disabled in order to validate the gateway service and route can reach the upstream GraphQL service, and then throughout the tutorial we will enable each plugin.

Execute the deck sync command below to push up the gateway configuration. If you used a different runtime group please correct for that.

```console
deck sync --state kong.yaml --konnect-token <your-pat> --konnect-runtime-group-name default
```

Once the deck file has been synced in, take a moment to navigate konnect and review the configuration.

### Insomnia Configuration

From Insomnia we will test that we call graphql query via the Konnect gateway running on our local workstation.

Open Insomnia and import the `insomnia.yaml` Project, and open the `Quickstart Collection`.

Execute the `MyQuery-Konnect-kong_id` Request, and you should see a 200 status code with a response

```json
{
	"data": {
		"frankfurter_currency_list": {
			"AUD": "Australian Dollar",
			"BGN": "Bulgarian Lev",
			"BRL": "Brazilian Real",
			"CAD": "Canadian Dollar",
			"CHF": "Swiss Franc",
			"CNY": "Chinese Renminbi Yuan",
			"CZK": "Czech Koruna",
			"DKK": "Danish Krone",
			"EUR": "Euro",
			"GBP": "British Pound",
			"HKD": "Hong Kong Dollar",
			"HUF": "Hungarian Forint",
			"IDR": "Indonesian Rupiah",
			"ILS": "Israeli New Sheqel",
			"INR": "Indian Rupee",
			"ISK": "Icelandic Króna",
			"JPY": "Japanese Yen",
			"KRW": "South Korean Won",
			"MXN": "Mexican Peso",
			"MYR": "Malaysian Ringgit",
			"NOK": "Norwegian Krone",
			"NZD": "New Zealand Dollar",
			"PHP": "Philippine Peso",
			"PLN": "Polish Złoty",
			"RON": "Romanian Leu",
			"SEK": "Swedish Krona",
			"SGD": "Singapore Dollar",
			"THB": "Thai Baht",
			"TRY": "Turkish Lira",
			"USD": "United States Dollar",
			"ZAR": "South African Rand"
		},
		"frankfurter_convertedAmount": 9.73042
	}
}
```

## Tutorial

### Step 1 - OIDC Plugin

Now, we've validated the gateway setup is working. So the first activity will be to enable the OIDC, and validate the behavior.

#### Enable the OIDC Plugin

In Konnect, navigate to the runtime manager --> to the `graphql Route` --> Go to the Plugins Tab --> Toggle on the OIDC plugin.

When the OIDC plugin is enabled, the api call to the graphql endpoint should throw a `401 unauthorized`.

#### Validate Behavior

1. From Insomnia, execute the `MyQuery-Konnect-kong_id` Request, and you should see a `401 unauthorized`

Because we have implemented the `client_credentials` flow, we need to provide the client_id and client secret along with the graphql query.

2. In the `MyQuery-Konnect-kong_id` Request -->  go to the Auth Tab on the request --> select `Basic Auth` -->  add username --> `kong_id` and password --> the corresponding client secret you copied from Keycloak.

3. Execute the request again and you should get a 200 response.

4. Open the `MyQuery-Konnect-customer_id` Request and repeate the same process but with the `customer_id` username and secret. You should see a 200 response.

### Step 2 - OPA Plugin

With OIDC plugin correctly configured and validated, we can begin understanding how to rely on the OPA plugin for graphql authorization.

#### Understanding the graphql.rego OPA Policy

OPA language has GraphQL built-in functions that support parsing queries/mutations, verifying against a schema, and traversing the abstract syntax tree. We used the functions to build a graphql authorization strategy relying on parsing claims out of the JWT provided by the OIDC integration.

The core logic shows how to:

1. Parse query to AST and validate against the schema

2. Restricts the access controls based on claims. In this case kong_id users have more access than the customer_id users.

3. Parse input constants and validate those values

4. Parse input query variables and validate those values

Read through the entire graphql.rego file for the full list of helper functions to support the OPA rules, but the core logic is defined below.

```bash
#Parse Query to Abstract Syntax Tree and Validate against Schema
query_ast := graphql.parse_and_verify(input.request.http.parsed_body.query, schema)[1]

...extra logic...read the whole file....

# Allow kong_id client_id to convert from EUR
allowed_kong_query(q) {
	is_kong_id

	#constant value example
	valueRaw := constant_string_arg(q, "from")
	valueRaw == "EUR"

	#look up var in variables example
	amountVar := variable_arg(q, "amount")
	amount := input.request.http.parsed_body.variables[amountVar]
	amount > 5
}
```

#### Enable OPA Plugin

Navigate back to the route in Konnect and enable the OPA plugin.

Now that the OPA Plugin has been configured we can play with the graphql query request to validate the behavior.

### Step 3 - Testing kong user Authorization

Open the `MyQuery-Konnect-kong_id` Request in Insomnia.

**Test 1 - kong user query that are allowed**

* Set the `amount` in the query variables to `10.00`
* Set `from` in the query to `EUR`

Outcome: You should see a 200 response with data

<p align="center">
    <img src="img/tutorial/test-1-kong_id_successful.png" width=1000/></div>
</p>

**Test 2 - kong user queries that are NOT allowed**

* Set  the `amount` in the query variables to `4.9`

Outcome: You should see a `403 Forbidden` Status and a json response:

<p align="center">
    <img src="img/tutorial/test-2-kong_id_unsuccesful.png" width=1000/></div>
</p>

* Change amount in the query variables back to `10.00`
* Set `from` in the query to `MYR`

Outcome: You should see a `403 Forbidden` Status

<p align="center">
    <img src="img/tutorial/test-2-kong_id_unsuccesful_b.png" width=1000/></div>
</p>

Nice - so we've tested through several type of possible access controls, using constants, and query variables, also parsing out a claim from the JWT.

### Step 4 - Testing customer user Authorization

Open the `MyQuery-Konnect-customer_id` Request in Insomnia.

**Test 3 - customer user queries that are allowed**

* Execute the query in insomnia with no changes,

Outcome: You should see a `200` Status

<p align="center">
    <img src="img/tutorial/test-3-customer_id_successful.png" width=1000/></div>
</p>

**Test 4 - customer user queries that are NOT allowed**

* Copy the `frankfurter_convertedAmount(amount: $amount, from: "EUR", to: "CHF")` into the query and update query inputs (look at the screenshot below)

Outcome: You should again see a `403 Forbidden` status code.

<p align="center">
    <img src="img/tutorial/test-4-customer_id_unsuccessful.png" width=1000/></div>
</p>

### Conclusion

Nice - so we've tested through several type of possible access controls, using constants, and query variables, also parsing out a claim from the JWT, all surrounding a GraphQL API!

## Cleaup

1. Tear down the konnect docker container:

```console
docker kill <container-name>
```

Tear down the Keycloak and OPA docker containers:

```console
docker compose down
```

And you're basically all cleaned up.

### Summary

This tutorial covered how to provide Authentication and Authorization to a GraphQL API with Konnect and OPA.

We hope this was insightful and fun. If you want to reach us, ask questions, or any other asks for patterns please open up an issue on this repo!

From yours truly - The Kong Partner Engineering Team
