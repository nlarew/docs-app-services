curl "https://realm.mongodb.com/api/admin/v3.0/groups/$PROJECT_ID/apps/$APP_ID/auth_providers" \
  -X "POST" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "custom-token",
    "type": "custom-token",
    "disabled": false,
    "config": {
      "audience": ["<Your Firebase Project ID>"],
      "jwkURI": "https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com",
      "useJWKURI": true
    },
    "secret_config": {
      "signingKeys": []
    },
    "metadata_fields": [
      {
        "required": false,
        "name": "firebase.identities.email",
        "field_name": "emails"
      },
      {
        "required": false,
        "name": "firebase.sign_in_provider",
        "field_name": "signInProvider"
      },
      {
        "required": false,
        "name": "user_id",
        "field_name": "userId"
      },
      {
        "required": false,
        "name": "email_verified",
        "field_name": "emailVerified"
      },
      {
        "required": false,
        "name": "email",
        "field_name": "email"
      }
    ]
  }'
