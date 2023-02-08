# Konnect - Stepzen Graphql Authorization Story

The objective of this story is to demonstrate how to apply current authorization practices of graphql apis with Konnect and Stepzen.

The prequisites for the tutorial:

1. Konnect Enterprise Account - for use of OIDC and OPA Plugin
2. Stepzen Account
3. npm install to run stepzen quickstart
4. Docker and docker compose
5. Insomnia

## Environment Setup

### Stepzen Quickstart NPM process

Followed the describe on Stepzen's Getting Started with Graphql Example `https://stepzen.com/getting-started?details=examples`.

```console
stepzen import graphql
```

### Keycloak and Opa - Docker Containers

Docker compose file will create three components: kong-net docker network, opa container, and keycloak container.

```console
docker compose up
```

### Konnect DP - Docker Container

Login into Konnect at `https://cloud.konghq.com/`

**Create the Konnect Runtime instance**

In the `default` runtime group create a new runtime instance --> Select Linux(Docker) --> Select `Generate script`

Copy the script and run in the terminal on your local workstation.

You should see the gateway successfully connected under `Runtime Instances` menu.

**Join the Konnect runtime instance to kong-net docker network**

Navigate back to the terminal to add the konnect gateway to the `kong-net` docker network.

1. Grab the container name:

```console
KONNECT_DP=$(docker ps --format '{{json .}}' |  jq -s 'map({name:.Names,Image:.Image})' | jq '.[] | select (.Image=="kong/kong-gateway:3.1.0.0")' | jq -r '.name')
```

2. Add container to `kong-net`

```console
docker network connect kong-net $KONNECT_DP
```

3. Need to restart the container to pick up the services

```console
docker restart $KONNECT_DP
```

## Tutorial Stepzen Graphql Authorization with Konnect

### Keycloack create clients

You will create two clients in Keycloak, `kong_id` and `customer_id` that will be setup with `client_credentials` OAuth flow.

Login to keycloak on `http:localhost:8080/admin` with username - admin and password - admin.

#### Create Realm - kong

In the master drop down menu, select `Create Realm` and create the `kong` realm.

#### Create Client - kong_id and customer_id

This example will step through how to make the `kong_id,` please repeat the exact steps for customer_id as well.

1. In the left-panel the kong realm should be selected --> Navigate to clients --> select `create client` in the main panel --> fill in `Client ID` with `kong_id`

2. Select Next --> Toggle on client authentication, and for Authentication Flow toggle `Standard Flow` and `Service account roles` --> Save

3. Navigate to Credentials Tab and grab the client secret. Save the client secret for later.

* Repeat this process for `customer_id`.

### Deck Sync - Gateway Service, Route, and Route Plugins

The deck sync command will sync into the default runtime group to create:

* a gateway service
* route
* OIDC plugin - on the route
* OPA plugin - on the route

Both the plugins will be disabled in order to validate the gateway service and route can reach the backend graphql.

Execute the deck sync command below to push up the gateway configuration.

```console
deck sync --state kong.yaml --konnect-token <your-pat> --konnect-runtime-group-name default
```

Once the deck file has been synced in, take a moment to navigate konnect and review the configuration.

### Insomnia

Open Insomnia and import the `insomnia-kong-stepzen-authZ.json` Collection.

From Insomnia we will test that we call graphql query via the Konnect gateway running on our local workstation. Execute the `MyQuery-Konnect-kong_id` Request.

### OIDC Plugin

Navigate to the `stepzen Route` --> Toggle on the OIDC plugin. When the OIDC plugin is enabled, the api call to the graphql endpoint will throw a `401 unauthorized`.

Because we have implemented the `client_credentials` flow, we need to provide the client_id and client secret along with the graphql query. To fix that, in the insomnia interface, go to the Auth Tab on the request, and add username --> kong_id and password -->  corresponding client secret for Basic Auth parameters.

Execute the request again and you should get a 200 response.

### OPA Plugin

With OIDC plugin correctly configured and validated, we can begin understanding how to rely on the OPA plugin for graphql authorization.

#### Understanding the grpahql.rego OPA Policy

OPA recently released new builtin functions to help support graphql authorization. with the built-in functions queries can be parsed, verified against a schema, and traversed. We used the new functions to build a graphql authorization strategy relying on the JWT validated by the OIDC plugin.

The core logic for the policy defines the following:

1. only client_id `kong_id` is permitted to query the `frankfurter_convertedAmount` with `EUR` in the `from` field.
2. all client_id `kong_id` and `customer_id` in this case, are permitted to query `frankfurter_currency_list`.

Read through the entire graphql.rego file for the full list of helper functions to support the OPA rules, but the core logic is defined below.

```rego
default allow := false
query_ast := graphql.parse_query(input.request.http.parsed_body.query)

allow {
	frankfurterConvertedAmountQueries != {}
	print(query_ast)
	every query in frankfurterConvertedAmountQueries {
		allowed_kong_query(query)
	}
    
   every query in frankfurterCurrencyList{
   	allowed_public_query(query)
   }
}

# Allow kong_id client_id to convert from EUR
allowed_kong_query(q) {
	is_kong_id
	valueRaw := constant_string_arg(q, "from")
	valueRaw == "EUR"
}

#Allow all generic users to query list of of currencies
allowed_public_query(q) {
	is_realm_access_default
}

# Helper functions.

# Build up an object with all queries of interest as values from frankfurter_convertedAmount
frankfurterConvertedAmountQueries[value] {
	some value
	walk(query_ast, [_, value])
	value.Name == "frankfurter_convertedAmount"
}

# Build up an object with all queries of interest as values from frankfurter_currency_list
frankfurterCurrencyList[value] {
	some value
	walk(query_ast, [_, value])
	value.Name == "frankfurter_currency_list"
}
```

#### Apply the OPA policy to the OPA Server and Enable OPA Plugin on the Route.

Execute the http request below to put the policy on the local opa server.

```console
curl -XPUT http://localhost:8181/v1/policies/graphql --data-binary @opa/graphql.rego
```

Navigate into the Route Configuration on Konnect, and enable the OPA plugin.

Now that the OPA Plugin has been configured we can play with the graphql query request to validate the behavior.

**I - kong_id client id requests**

The kong_id should be able to execute this query:

```console
query MyQuery {
  frankfurter_convertedAmount(amount: 1.5, from: "EUR", to: "CHF")
  frankfurter_currency_list
}
```

But the query below should return a 403 - Forbidden:

```console
query MyQuery {
  frankfurter_convertedAmount(amount: 1.5, from: "AUD", to: "CHF")
  frankfurter_currency_list
}
```

**II - customer_id requests**

The customer is only permitted to query the following:

```console
query MyQuery {
  frankfurter_currency_list
}
```

You should see that this query below returns a 403 - Forbidden:

```console
query MyQuery {
  frankfurter_convertedAmount(amount: 1.5, from: "AUD", to: "CHF")
  frankfurter_currency_list
}
```

