package graphql

import future.keywords.every
import future.keywords.in


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

####SCHEMA
schema := `
type Frankfurter_Latest_Rates {
  amount: Float
  base: String
  date: Date
  rates: JSON
}

type Frankfurter_Historical_Rates {
  base: String
  amount: Float
  date: Date
  rates: JSON
}

type Frankfurter_TimeSeries_Rates {
  base: String
  amount: Float
  start_date: Date
  end_date: Date
  rates: JSON
}

type IpApi_Location {
  status: String
  message: String
  continent: String
  continentCode: String
  country: String
  countryCode: String
  region: String
  regionName: String
  city: String
  district: String
  zip: String
  lat: Float
  lon: Float
  timezone: String
  offset: Int
  currency: String
  isp: String
  org: String
  as: String
  reserve: String
  mobile: Boolean
  proxy: Boolean
  hosting: Boolean
  ip: String
  priceInCountry(amount: Float!, from: String!): Float
    @materializer(
      query: "frankfurter_convertedAmount"
      arguments: [
        { name: "to", field: "currency" }
        { name: "amount", argument: "amount" }
        { name: "from", argument: "from" }
      ]
    )
}

type IpApi_StepZen_Request {
  clientIp: String
}

type Query {
  frankfurter_latest_rates(
    from: String
    to: String
    amount: Float
  ): Frankfurter_Latest_Rates
  frankfurter_historical_rates(
    from: String
    to: String
    amount: Float
    date: Date
  ): Frankfurter_Historical_Rates
  frankfurter_time_series(
    from: String
    to: String
    amount: Float
    start_date: Date
    end_date: Date
  ): Frankfurter_TimeSeries_Rates
  frankfurter_currency_list: JSON
  frankfurter_convertedAmount(
    amount: Float!
    from: String!
    to: String!
  ): Float
  ipApi_location(ip: String!, lang: String! = "en"): IpApi_Location
  ipApi_stepzen_request: IpApi_StepZen_Request @connector(type: "request")
  ipApi_location_Auto(lang: String! = "en"): IpApi_Location
}
`