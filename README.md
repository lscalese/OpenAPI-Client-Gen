## OPENAPI Client Gen

This is an application to generate a [simple REST Http client](#Simple-Http-Client-Sample) or an [Iris interoperability production](#Production-Sample) client from a OpenAPI specification.  
Instead of existing tools, this application generates client production.

It could be used as tool to create production on your local instance or to be hosted.  
If this application is hosted, a REST api is available to upload the specification document and download the generated classes.  

All generated classes are ABSOLUTELY NOT linked in any way with the generator.  
Feel free to edit anything to adapt it with your need.  
Consider the generated Production\classes client as a template ready to use.  
&nbsp;
## Table of contents  
&nbsp;
1. [Installation ZPM](https://github.com/lscalese/OpenAPI-Client-Gen/blob/master/README.md#Installation-ZPM)
2. [Installation Docker](https://github.com/lscalese/OpenAPI-Client-Gen/blob/master/README.md#Installation-Docker)  
3. [Production Sample](https://github.com/lscalese/OpenAPI-Client-Gen/blob/master/README.md#Production-Sample)  
4. [Simple Http Client Sample](https://github.com/lscalese/OpenAPI-Client-Gen/blob/master/README.md#Simple-Http-Client-Sample)  

&nbsp;

## Installation ZPM

You need a namespace with interoperability enabled.  

If needed, You can enable the interoperability with:
```
Do ##class(%Library.EnsembleMgr).EnableNamespace($Namespace, 1)
```

Installation openapi-client-gen:
```
zpm "install openapi-client-gen"
```

There are dependencies, the following packages will be also installed:

 * [objectscript-openapi-definition](https://openexchange.intersystems.com/package/objectscript-openapi-definition)  
 * [yaml-utils](https://openexchange.intersystems.com/package/yaml-utils)  
 * [swagger-converter-cli](https://openexchange.intersystems.com/package/swagger-converter-cli)  
 * [swagger-validator-cli](https://openexchange.intersystems.com/package/swagger-validator-cli)  

## Installation Docker

Clone/git pull the repo into any local directory

```bash
git clone https://github.com/lscalese/OpenAPI-Client-Gen.git
cd OpenAPI-Client-Gen
docker-compose up -d
```
  
## Production Sample

In this sample we generate a production client for [petshop V3 API](https://petstore3.swagger.io/) REST Api  
from the [specification 3.0](https://petstore3.swagger.io/api/v3/openapi.json).  

### Generate interoperatibility classes

Let's start by generate interoperability classes from [petshop swagger V3](https://petstore.swagger.io/).  

```
Zn "irisapp"
Set sc = ##class(dc.openapi.client.Spec).generateApp("petshop", "https://petstore3.swagger.io/api/v3/openapi.json")
Write !,"Status : ",$SYSTEM.Status.GetOneErrorText(sc)
```
The first argument is the package name where the classes will be generated and the second is the OpenAPI specification URL.  
Also the [method](https://github.com/lscalese/OpenAPI-Client-Gen/blob/master/src/dc/openapi/client/Spec.cls#L11) accept a filename or a dynamic object.  
The generator accept :  

 * JSON format.  
 * YAML format (using [yaml-utils](https://openexchange.intersystems.com/package/yaml-utils) to convert in JSON format).  
 * Swagger specification version 1.x, 2.x, 3.x but version 1.x and 2.x will be converted in version 3.0 using [swagger-converter-cli](https://openexchange.intersystems.com/package/swagger-converter-cli) before processing.  


Take a look on these generated classes:  

* **Business service classes**  
BusinessService classes are in the sub-package `services`.  There is a Business Service for each request defined in the specification document.  
The generated classes are templates which should be edited with your need.  


* **Ens.Request classes**  
For each request defined, an Ens.Request class are located in the sub-package `requests`.  
This class represent all of parameters (query parameters, path, body, headers, formdata).  
The Business operation will consume an instance of this class to generate a related http request.  

* **GenericResponse class**  
The Ens.Response generated subclass is named "package.GenericResponse" (petshop.responses.GenericResponse in this sample).  
It contains some properties to store the body response, headers, http status code, performed operation and status.  

* **Business Process class**  
The generated Business process name is simply packageName.Process (petshop.bp.Process in this sample).  
This is a basic implementation that redirect all messages to the Business Operation.  

* **Business Operation class**  
Probably the most usefull generated class in this project  (petshop.bo.Operation in this sample)..  
It contain a method for each request and build a %Net.HttpRequest instance from the Ens.Request subclass.  
A message map XDATA is also generated to call automatically the related method for the received message.  

* **Production class**  
A pre-configured production is also generated named pakagename.Production (petshop.Production in this sample).  
All Business Services are disabled by default.  
  
  
### Configure a production  

Open and start petshop.Production from [production page](http://localhost:52773/csp/irisapp/EnsPortal.ProductionConfig.zen).    
This is the auto generated production.  
<img width="1123" src="https://raw.githubusercontent.com/lscalese/OpenAPI-Client-Gen/master/assets/Production-Open-1.png">

Great!  Our production is ready.  

## Code snipet

You can find code snipet in the [sames petshop class](https://github.com/lscalese/OpenAPI-Client-Gen/blob/master/src/dc/openapi/client/samples/PetShop.cls).  

### Add Pet

Let's start by add a pet to the public REST service petstore.  

**Add a pet to Petstore :**  

```
Set messageRequest = ##class(petshop.requests.addPet).%New(), 
Set messageRequest.%ContentType = "application/json"

Set messageRequest.body1 = ##class(petshop.model.Pet).%New()
Do messageRequest.body1.%JSONImport({"id":123,"name":"Kitty Galore","photoUrls":["https://localhost/img.png"],"status":"pending"})

Set sc = ##class(petshop.Utils).invokeHostSync("petshop.bp.SyncProcess", messageRequest, "petshop.bs.ProxyService", , .pResponse)

If $$$ISERR(sc) Do $SYSTEM.Status.DisplayError(sc)
```



<img width="1123" src="https://raw.githubusercontent.com/lscalese/OpenAPI-Client-Gen/master/assets/Visual-Trace.png">

The example below use the interoperability framework, so there is another way if you don't want use the framework.  
The following example allows to create a pet with a simple http client:  

```
Set messageRequest = ##class(petshop.requests.addPet).%New()

Set messageRequest.%ContentType = "application/json"
Set messageRequest.body1 = ##class(petshop.model.Pet).%New()

Do messageRequest.body1.%JSONImport({"id":123,"name":"Kitty Galore","photoUrls":["https://localhost/img.png"],"status":"pending"})

Set httpClient = ##class(petshop.HttpClient).%New("https://petstore3.swagger.io/api/v3","DefaultSSL")

Set sc = httpClient.addPet(messageRequest, .messageResponse)
; If needed, you have a direct access to the %Net.HttpResquest in `httpClient.HttpRequest` property.  

If $$$ISERR(sc) Do $SYSTEM.Status.DisplayError(sc) Quit sc

Write !,"Http Status code : ", messageResponse.httpStatusCode,!
Do messageResponse.Pet.%JSONExport()
```

### Generate a simple client application

By default generator produces classes for interoperability framework and a simple http client.  
If you don't only the simple http client without interoperability classes, you can use the following command:  

```
Set features("simpleHttpClientOnly") = 1
Set sc = ##class(dc.openapi.client.Spec).generateApp("petshopclient", "https://petstore.swagger.io/v2/swagger.json", .features)
```

## Useful command

### Generate production on local machine

By URL
```
Set sc = ##class(dc.openapi.client.Spec).generateApp("petshop", "https://petstore3.swagger.io/api/v3/openapi.json")
```
By filename, ex:
```
Set sc = ##class(dc.openapi.client.Spec).generateApp("petshop", "/irisdev/app/petshop.json")
```
By DynamicObject

```
Set spec = {} ; Set your specficiation here
Set sc = ##class(dc.openapi.client.Spec).generateApp("petshop", spec)
```

### Generate simple Http Client (without Interoperability architecture)

```
Set features("simpleHttpClientOnly") = 1
Set sc = ##class(dc.openapi.client.Spec).generateApp("simpleclient", "https://petstore3.swagger.io/api/v3/openapi.json", .features)
```

### Generate classes for export code purpose only

```
TSTART
Set features("compile") = 0
Set sc = ##class(dc.openapi.client.Spec).%CreateClientApplication(appName, spec, .features)
Do $SYSTEM.OBJ.ExportPackageToStream(appName, .xmlStream)
TROLLBACK ; Code has been exported to xmlStream, a simple TROLLBACK delete all generated definition in code database.
```
