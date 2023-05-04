

oneTimeSetUp() {
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
  echo "Successfully prepared test collections"
}

oneTimeTearDown() {
  [[ "${_shunit_name_}" = 'EXIT' ]] && return 0 # need this to suppress tearDown on script EXIT because apparently "one time" does not mean "only once"...
  # Nuke the App from orbit. It's the only way to be sure. https://www.youtube.com/watch?v=aCbfMkh940Q
  ## Delete all of our test data
  deleteAllDocuments "learn-data-api" "hello"
  deleteAllDocuments "learn-data-api" "data-types"
  ## Delete the App
  npx mongodb-realm-cli app delete --profile $APP_NAME --app $CLIENT_APP_ID
  rm -rf $APP_NAME
}






testBinary() {
  result=$(
    # :snippet-start: Binary
    # :replace-start: {
    #    "terms": {
    #       "mongodb-atlas": "<cluster name>",
    #       "learn-data-api": "<database name>",
    #       "data-types": "<collection name>",
    #       " \"_id\": { \"$oid\": \"645404f4ee8583002fc5a77e\" },": ""
    #    }
    # }
    curl -s https://data.mongodb-api.com/app/$CLIENT_APP_ID/endpoint/data/v1/action/insertOne \
      -x POST \
      -H "apiKey: $API_KEY" \
      -H 'Content-Type: application/ejson' \
      -H "Accept: application/json" \
      -d '{
        "dataSource": "mongodb-atlas",
        "database": "learn-data-api",
        "collection": "data-types",
        "document": { "_id": { "$oid":"645404f4ee8583002fc5a77e" },
          "data": {
            "$binary": {
              "base64": "46d989eaf0bde5258029534bc2dc2089",
              "subType": "05"
            }
          }
        }
      }'
    # :replace-end:
    # :snippet-end:
  )
  local insertedId=$(jq -r ".insertedId" <<< "$result")
  assertEquals "645404f4ee8583002fc5a77e" $insertedId
}


testDate() {
  canonicalResult=$(
    # :snippet-start: Date-Canonical
    # :replace-start: {
    #    "terms": {
    #       "mongodb-atlas": "<cluster name>",
    #       "learn-data-api": "<database name>",
    #       "data-types": "<collection name>",
    #       " \"_id\": { \"$oid\": \"64540a2ec3a295cbcce82163\" },": ""
    #    }
    # }
    curl -s https://data.mongodb-api.com/app/$CLIENT_APP_ID/endpoint/data/v1/action/insertOne \
      -x POST \
      -H "apiKey: $API_KEY" \
      -H 'Content-Type: application/ejson' \
      -H "Accept: application/json" \
      -d '{
        "dataSource": "mongodb-atlas",
        "database": "learn-data-api",
        "collection": "data-types",
        "document": { "_id": { "$oid": "64540a2ec3a295cbcce82163" },
          "createdAt": { "$date": { "$numberLong": "1638551310749" } }
        }
      }'
    # :replace-end:
    # :snippet-end:
  )
  local insertedId=$(jq -r ".insertedId" <<< "$canonicalResult")
  assertEquals "64540a2ec3a295cbcce82163" "$insertedId"

  relaxedResult=$(
    # :snippet-start: Date-Relaxed
    # :replace-start: {
    #    "terms": {
    #       "mongodb-atlas": "<cluster name>",
    #       "learn-data-api": "<database name>",
    #       "data-types": "<collection name>",
    #       " \"_id\": { \"$oid\": \"64540a585ed1111e93d02a6d\" },": ""
    #    }
    # }
    curl -s https://data.mongodb-api.com/app/$CLIENT_APP_ID/endpoint/data/v1/action/insertOne \
      -x POST \
      -H "apiKey: $API_KEY" \
      -H 'Content-Type: application/ejson' \
      -H "Accept: application/json" \
      -d '{
        "dataSource": "mongodb-atlas",
        "database": "learn-data-api",
        "collection": "data-types",
        "document": { "_id": { "$oid": "64540a585ed1111e93d02a6d" },
          "createdAt": { "$date": "2021-12-03T17:08:30.749Z" }
        }
      }'
    # :replace-end:
    # :snippet-end:
  )
  local insertedId=$(jq -r ".insertedId" <<< "$relaxedResult")
  assertEquals "64540a585ed1111e93d02a6d" "$insertedId"
}

testDecimal128() {
  result=$(
    # :snippet-start: Decimal128
    # :replace-start: {
    #    "terms": {
    #       "mongodb-atlas": "<cluster name>",
    #       "learn-data-api": "<database name>",
    #       "data-types": "<collection name>",
    #       " \"_id\": { \"$oid\": \"64540b2936fd7d4d69bf7faf\" },": ""
    #    }
    # }
    curl -s https://data.mongodb-api.com/app/$CLIENT_APP_ID/endpoint/data/v1/action/insertOne \
      -x POST \
      -H "apiKey: $API_KEY" \
      -H 'Content-Type: application/ejson' \
      -H "Accept: application/json" \
      -d '{
        "dataSource": "mongodb-atlas",
        "database": "learn-data-api",
        "collection": "data-types",
        "document": { "_id": { "$oid": "64540b2936fd7d4d69bf7faf" },
          "accountBalance": { "$numberDecimal": "128452.420523" }
        }
      }'
    # :replace-end:
    # :snippet-end:
  )
  local insertedId=$(jq -r ".insertedId" <<< "$result")
  assertEquals "64540b2936fd7d4d69bf7faf" "$insertedId"
}

testDouble() {
  canonicalResult=$(
    # :snippet-start: Double-Canonical
    # :replace-start: {
    #    "terms": {
    #       "mongodb-atlas": "<cluster name>",
    #       "learn-data-api": "<database name>",
    #       "data-types": "<collection name>",
    #       " \"_id\": { \"$oid\": \"645422189a49b0668a3d02c8\" },": ""
    #    }
    # }
    curl -s https://data.mongodb-api.com/app/$CLIENT_APP_ID/endpoint/data/v1/action/insertOne \
      -x POST \
      -H "apiKey: $API_KEY" \
      -H 'Content-Type: application/ejson' \
      -H "Accept: application/json" \
      -d '{
        "dataSource": "mongodb-atlas",
        "database": "learn-data-api",
        "collection": "data-types",
        "document": { "_id": { "$oid": "645422189a49b0668a3d02c8" },
          "temperatureCelsius": { "$numberDouble": "23.847" }
        }
      }'
    # :replace-end:
    # :snippet-end:
  )
  local insertedId=$(jq -r ".insertedId" <<< "$canonicalResult")
  assertEquals "645422189a49b0668a3d02c8" "$insertedId"

  relaxedResult=$(
    # :snippet-start: Double-Relaxed
    # :replace-start: {
    #    "terms": {
    #       "mongodb-atlas": "<cluster name>",
    #       "learn-data-api": "<database name>",
    #       "data-types": "<collection name>",
    #       " \"_id\": { \"$oid\": \"6454220b8962b2a4728da6c2\" },": ""
    #    }
    # }
    curl -s https://data.mongodb-api.com/app/$CLIENT_APP_ID/endpoint/data/v1/action/insertOne \
      -x POST \
      -H "apiKey: $API_KEY" \
      -H 'Content-Type: application/ejson' \
      -H "Accept: application/json" \
      -d '{
        "dataSource": "mongodb-atlas",
        "database": "learn-data-api",
        "collection": "data-types",
        "document": { "_id": { "$oid": "6454220b8962b2a4728da6c2" },
          "temperatureCelsius": 23.847
        }
      }'
    # :replace-end:
    # :snippet-end:
  )
  local insertedId=$(jq -r ".insertedId" <<< "$relaxedResult")
  assertEquals "6454220b8962b2a4728da6c2" "$insertedId"
}

testInt32() {
  canonicalResult=$(
    # :snippet-start: Int32-Canonical
    # :replace-start: {
    #    "terms": {
    #       "mongodb-atlas": "<cluster name>",
    #       "learn-data-api": "<database name>",
    #       "data-types": "<collection name>",
    #       " \"_id\": { \"$oid\": \"645421b3d5068899e28a489d\" },": ""
    #    }
    # }
    curl -s https://data.mongodb-api.com/app/$CLIENT_APP_ID/endpoint/data/v1/action/insertOne \
      -x POST \
      -H "apiKey: $API_KEY" \
      -H 'Content-Type: application/ejson' \
      -H "Accept: application/json" \
      -d '{
        "dataSource": "mongodb-atlas",
        "database": "learn-data-api",
        "collection": "data-types",
        "document": { "_id": { "$oid": "645421b3d5068899e28a489d" },
          "coins": { "$numberInt": "2147483647" }
        }
      }'
    # :replace-end:
    # :snippet-end:
  )
  local insertedId=$(jq -r ".insertedId" <<< "$canonicalResult")
  assertEquals "645421b3d5068899e28a489d" "$insertedId"

  relaxedResult=$(
    # :snippet-start: Int32-Relaxed
    # :replace-start: {
    #    "terms": {
    #       "mongodb-atlas": "<cluster name>",
    #       "learn-data-api": "<database name>",
    #       "data-types": "<collection name>",
    #       " \"_id\": { \"$oid\": \"645421df8fd5ee797aa1d2a9\" },": ""
    #    }
    # }
    curl -s https://data.mongodb-api.com/app/$CLIENT_APP_ID/endpoint/data/v1/action/insertOne \
      -x POST \
      -H "apiKey: $API_KEY" \
      -H 'Content-Type: application/ejson' \
      -H "Accept: application/json" \
      -d '{
        "dataSource": "mongodb-atlas",
        "database": "learn-data-api",
        "collection": "data-types",
        "document": { "_id": { "$oid": "645421df8fd5ee797aa1d2a9" },
          "coins": 2147483647
        }
      }'
    # :replace-end:
    # :snippet-end:
  )
  local insertedId=$(jq -r ".insertedId" <<< "$relaxedResult")
  assertEquals "645421df8fd5ee797aa1d2a9" "$insertedId"
}

testInt64() {
  result=$(
    # :snippet-start: Int64
    # :replace-start: {
    #    "terms": {
    #       "mongodb-atlas": "<cluster name>",
    #       "learn-data-api": "<database name>",
    #       "data-types": "<collection name>",
    #       " \"_id\": { \"$oid\": \"645421504f95e28eeb2a8dba\" },": ""
    #    }
    # }
    curl -s https://data.mongodb-api.com/app/$CLIENT_APP_ID/endpoint/data/v1/action/insertOne \
      -x POST \
      -H "apiKey: $API_KEY" \
      -H 'Content-Type: application/ejson' \
      -H "Accept: application/json" \
      -d '{
        "dataSource": "mongodb-atlas",
        "database": "learn-data-api",
        "collection": "data-types",
        "document": { "_id": { "$oid": "645421504f95e28eeb2a8dba" },
          "population": { "$numberLong": "8047923148" }
        }
      }'
    # :replace-end:
    # :snippet-end:
  )
  local insertedId=$(jq -r ".insertedId" <<< "$result")
  assertEquals "645421504f95e28eeb2a8dba" "$insertedId"
}

testObjectId() {
  result=$(
    # :snippet-start: ObjectId
    # :replace-start: {
    #    "terms": {
    #       "mongodb-atlas": "<cluster name>",
    #       "learn-data-api": "<database name>",
    #       "data-types": "<collection name>"
    #    }
    # }
    curl -s https://data.mongodb-api.com/app/$CLIENT_APP_ID/endpoint/data/v1/action/insertOne \
      -x POST \
      -H "apiKey: $API_KEY" \
      -H 'Content-Type: application/ejson' \
      -H "Accept: application/json" \
      -d '{
        "dataSource": "mongodb-atlas",
        "database": "learn-data-api",
        "collection": "data-types",
        "document": {
          "_id": { "$oid": "61f02ea3af3561e283d06b91" }
        }
      }'
    # :replace-end:
    # :snippet-end:
  )
  local insertedId=$(jq -r ".insertedId" <<< "$result")
  assertEquals "61f02ea3af3561e283d06b91" "$insertedId"
}
