package graphql

import future.keywords.every
import future.keywords.in


schema := `
   type Query {
     frankfurter_currency_list: JSON
     frankfurter_convertedAmount(
       amount: Float!
       from: String!
       to: String!
     ): Float
   }
   scalar JSON
`

query_ast := graphql.parse_and_verify(input.request.http.parsed_body.query,schema)[0]

default allow := false

allow {
    
	frankfurterConvertedAmountQueries != {}
	every query in frankfurterConvertedAmountQueries {
		allowed_kong_query(query)
	}

	every query in frankfurterCurrencyList {
		allowed_public_query(query)
	}
}

# Allow kong_id client_id to convert from EUR
allowed_kong_query(q) {
	is_kong_id
	
	#constant value example
	valueRaw := constant_string_arg(q, "from")
	valueRaw == "EUR"

	#look up var in variables example
	amountVar := variable_arg(q, "amount")
	amount := input.request.http.parsed_body.variables[amountVar]
	amount > 2 
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

# Build up an object with all queries of interest as values from frankfurter_convertedAmount
frankfurterCurrencyList[value] {
	some value
	walk(query_ast, [_, value])
	value.Name == "frankfurter_currency_list"
}

# Extract the string value of a constant value argument.
constant_string_arg(value, argname) := arg.Value.Raw {
	some arg in value.Arguments
	arg.Name == argname
	arg.Value.Kind == 3
}

# Extract the variable name for a variable argument.
variable_arg(value, argname) := arg.Value.Raw {
	some arg in value.Arguments
	arg.Name == argname
	arg.Value.Kind == 0
}

# Helper JWT Functions
bearer_token := t {
	v := input.request.http.headers.authorization
	startswith(v, "Bearer ")
	t := substring(v, count("Bearer "), -1)
}

token = {"payload": payload} {
	[_, payload, _] := io.jwt.decode(bearer_token)
}

is_kong_id {
	token.payload.clientId == "kong_id"
}

is_realm_access_default {
	"default-roles-kong" in token.payload.realm_access.roles
}