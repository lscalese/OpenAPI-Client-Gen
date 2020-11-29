Class dc.openapi.client.api.spec Extends %REST.Spec [ ProcedureBlock ]
{

XData OpenAPI [ MimeType = application/json ]
{
{
  "swagger":"2.0",
  "info":{
    "title":"Open API Client Gen",
    "version":"1.0",
    "contact":{
      "email":"lorenzo.scalese@gmail.com"
    }
  },
  "basePath":"/swaggerclientgen/api",
  "schemes":[
    "https",
    "http"
  ],
  "paths":{
    "/interopclasses/{appName}":{
      "post":{
        "summary":"Generate IRIS Interoperability client classes from OPEN API Specification.",
        "description":"Generate IRIS Interoperability client classes from OPEN API Specification.",
        "consumes":[
          "application/json"
        ],
        "produces":[
          "application/xml"
        ],
        "operationId":"InteropClasses",
        "parameters":[
          {
            "in":"body",
            "name":"body",
            "description":"Open API Specification",
            "required":true,
            "schema":{
            }
          },
          {
            "name":"appName",
            "in":"path",
            "description":"package name for your application.",
            "required":true,
            "type":"string"
          },
          {
            "name":"simpleHttpClient",
            "in":"query",
            "description":"If set to 1, the generated code won't a production but a simple http client without Interoperability architecture.",
            "required":false,
            "type":"string"
          }
        ],
        "responses":{
          "200":{
            "description":"OK - download generated classes in xml format."
          },
          "500":{
            "description":"ERROR."
          }
        }
      }
    },
    "/_spec":{
      "get":{
        "tags":[
          "Developers"
        ],
        "summary":"OpenAPI spec 2.0",
        "description":"OpenAPI spec 2.0 .\n",
        "produces":[
          "application/json"
        ],
        "operationId":"SwaggerSpec",
        "parameters":[
        ],
        "responses":{
          "200":{
            "description":"..."
          }
        }
      }
    }
  }
}
}

}
