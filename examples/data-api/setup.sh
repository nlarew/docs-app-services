create_data_api_app () {
  local APP_NAME="$1"
  # Create a new App Services App for this test run
  echo "Creating a new App Services App..."
  npx -y mongodb-realm-cli login --profile $APP_NAME --api-key $ATLAS_PUBLIC_API_KEY --private-api-key $ATLAS_PRIVATE_API_KEY
  npx mongodb-realm-cli app create --profile $APP_NAME --name $APP_NAME --cluster $CLUSTER_NAME --cluster-service-name "mongodb-atlas" --location "US-VA" --deployment-model "GLOBAL"
  cd $APP_NAME

  # Save the App ID as a global variable for use in the tests
  CLIENT_APP_ID=$(jq -r ".app_id" ./realm_config.json)

  # Configure the App
  echo "Configuring the App..."
  ## Configure Data API
  local DataApiConfig='{"disabled":false,"versions":["v1"],"return_type":"EJSON"}'
  echo $DataApiConfig > http_endpoints/data_api_config.json
  ## Configure Auth Providers
  local ApiKeyConfig='{"name":"api-key","type": "api-key","disabled":false}'
  local EmailPasswordConfig='{"name":"local-userpass","type":"local-userpass","config":{"autoConfirm":true,"resetPasswordUrl":"https://www.example.com/reset-password","resetPasswordSubject":"Fake Reset Your Password (If you got this email it was a mistake!)"},"disabled":false}'
  local AuthProvidersConfig='{"api-key":'$ApiKeyConfig',"local-userpass":'$EmailPasswordConfig'}'
  echo $AuthProvidersConfig > auth/providers.json
  # Configure rules
  local DefaultRulesConfig='{"roles":[{"name":"readAndWriteAll","apply_when":{},"document_filters":{"write":true,"read":true},"read":true,"write":true,"insert":true,"delete":true,"search":true}],"filters":[]}'
  echo $DefaultRulesConfig > data_sources/mongodb-atlas/default_rule.json
  ## Deploy the updates
  npx mongodb-realm-cli push --profile $APP_NAME --yes
  echo "Successfully configured the App"
  cd ..

  # Create users for the tests. Store credentials as global variables for use in the tests.
  echo "Creating test users..."
  local now=$(date +%s)
  ## Create an email/password user
  EMAIL="data-api-test-$now"
  PASSWORD="Passw0rd!"
  local emailPasswordResult=$(
    npx mongodb-realm-cli users create --profile $APP_NAME --app $CLIENT_APP_ID --type email --email $EMAIL --password $PASSWORD
  )
  echo "Successfully created email/password user: $EMAIL"
  ## Create an API Key user
  local apiKeyResult=$(
    npx mongodb-realm-cli users create --profile $APP_NAME --app $CLIENT_APP_ID --type api-key --name $EMAIL -f json
  )
  API_KEY=$(jq -r ".doc.key" <<< $apiKeyResult)
  echo "Successfully created API key user: $EMAIL"

  # Delete any existing data in the test collections, e.g. from other failed test runs
  echo "Preparing test collections..."
  deleteAllDocuments "learn-data-api" "hello"
  deleteAllDocuments "learn-data-api" "tasks"
  deleteAllDocuments "learn-data-api" "data-types"
  echo "Successfully prepared test collections"
}
