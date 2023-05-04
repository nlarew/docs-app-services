delete_data_api_app () {
  local APP_NAME="$1"
  [[ "${_shunit_name_}" = 'EXIT' ]] && return 0 # need this to suppress tearDown on script EXIT because apparently "one time" does not mean "only once"...
  # Nuke the App from orbit. It's the only way to be sure. https://www.youtube.com/watch?v=aCbfMkh940Q
  ## Delete all of our test data
  deleteAllDocuments "learn-data-api" "data-types"
  ## Delete the App
  npx mongodb-realm-cli app delete --profile $APP_NAME --app $CLIENT_APP_ID
  rm -rf $APP_NAME
}
