## OPENAPI Client Gen

This is an application to generate an Iris interoperability production from a Swagger 2.0 specification document.  
Instead of existing tools, this application generates client production.

It could be used as tool to create production on your local instance or to be hosted.  
If this application is hosted, a REST api is available to upload the specification document and download the generated classes.  

All generated classes are ABSOLUTELY NOT linked in any way with the generator.  
Feel free to edit anything to adapt it with your need.  
Consider the generated Production client as a template ready to use.  
  
## Production Sample

In this sample we generate a production client for [petshop Swagger 2.0 API](https://petstore.swagger.io/) REST Api  
from the [specification 2.0](https://petstore.swagger.io/v2/swagger.json).  

### Generate interoperatibility classes

Let's start by generate interoperability classes from [petshop Swagger 2.0 document](https://petstore.swagger.io/).  

```
Zn "irisapp"
Set sc = ##class(dc.openapi.client.Spec).generateApp("petshop", "https://petstore.swagger.io:443/v2/swagger.json")
Write !,"Status : ",$SYSTEM.Status.GetOneErrorText(sc)
```
The first argument is the package name where the classes will be generated and the second is the Swagger 2.0 specification URL.  
Also the [method](https://github.com/lscalese/OpenAPI-Client-Gen/blob/master/src/dc/openapi/client/Spec.cls#L11) accept a filename or a dynamic object.  


Take a look on these generated classes:  

* **Business service classes**  
BusinessService classes are suffixed by "Service".  There is a Business Service for each request defined in the specification document.  
The generated classes are templates which should be edited with your need.  


* **Ens.Request classes**  
For each request defined, an Ens.Request class is generated suffixed by "Request".  
This class represent all of parameters (query parameters, path, body, headers, formdata).  
The Business operation will consume an instance of this class to generate a related http request.  

* **GenericResponse class**  
The Ens.Response generated subclass is named "package.GenericResponse" (petshop.msg.GenericResponse in this sample).  
It contains some properties to store the body response, headers, http status code, performed operation and status.  

* **Business Process class**  
The generated Business process name is simply packageName.Process (petshop.bp.Process in this sample).  
This is a basic implementation that redirect all messages to the Business Operation.  

* **Business Operation class**  
Probably the most usefull generated class in this project.  
It contain a method for each request and build a %Net.HttpRequest instance from the Ens.Request subclass.  
A message map XDATA is also generated to call automatically the related method for the received message.  
A method "genericProcessResponse" is called after each request, feel free to edit with your need.  

* **Production class**  
A pre-configured production is also generated named pakagename.Production (petshop.Production in this sample).  
All Business Services are disabled by default.  

* **Rest Proxy application**  
Usefull for testing from an http client tools (petshop.REST class).  
We use curl command line in this sample.  
  
  
| Generated Classes | Description |
| --- | --- |
| petshop.Production | Production configuration |
| petshop.Utils | Utils class |
| petshop.bo.Operation | Busniness Operation |
| petshop.bp.Process | Generic Business Process |
| petshop.bs.ProxyService | Empty class to use for proxy rest application |
| petshop.bs.addPetService | addPetService Business Service |
| petshop.bs.createUserService | createUserService Business Service |
| petshop.bs.createUsersWithArrayInputService | createUsersWithArrayInputService Business Service |
| petshop.bs.createUsersWithListInputService | createUsersWithListInputService Business Service |
| petshop.bs.deleteOrderService | deleteOrderService Business Service |
| petshop.bs.deletePetService | deletePetService Business Service |
| petshop.bs.deleteUserService | deleteUserService Business Service |
| petshop.bs.findPetsByStatusService | findPetsByStatusService Business Service |
| petshop.bs.findPetsByTagsService | findPetsByTagsService Business Service |
| petshop.bs.getInventoryService | findPetsByTagsService Business Service |
| petshop.bs.getOrderByIdService | getOrderByIdService Business Service |
| petshop.bs.getPetByIdService | getPetByIdService Business Service |
| petshop.bs.getUserByNameService | getUserByNameService Business Service |
| petshop.bs.loginUserService | loginUserService Business Service |
| petshop.bs.logoutUserService | logoutUserService Business Service |
| petshop.bs.placeOrderService | placeOrderService Business Service |
| petshop.bs.updatePetService | updatePetService Business Service |
| petshop.bs.updatePetWithFormService | updatePetWithFormService Business Service |
| petshop.bs.updateUserService | updateUserService Business Service |
| petshop.bs.uploadFileService | uploadFileService Business Service |
| petshop.model.Definition.ApiResponse | ApiResponse model included in Request or response message |
| petshop.model.Definition.Category | Category model included in Request or response message |
| petshop.model.Definition.Order | Order model included in Request or response message |
| petshop.model.Definition.Pet |  Petmodel included in Request or response message |
| petshop.model.Definition.Tag | Tag model included in Request or response message |
| petshop.model.Definition.User | User model included in Request or response message |
| petshop.model.spec | Swagger 2.0 used for generate all classes |
| petshop.msg.GenericResponse | Generic Ens.Response |
| petshop.msg.ParsedResponse | Super class of models (petshop.mode.Definition) |
| petshop.msg.addPetRequest | addPet Ens.Request |
| petshop.msg.createUserRequest | createUser Ens.Request |
| petshop.msg.createUsersWithArrayInputRequest | reateUsersWithArrayInput Ens.Request |
| petshop.msg.createUsersWithListInputRequest | createUsersWithListInput Ens.Request |
| petshop.msg.deleteOrderRequest | deleteOrder Ens.Request |
| petshop.msg.deletePetRequest | deletePet Ens.Request |
| petshop.msg.deleteUserRequest | deleteUser Ens.Request |
| petshop.msg.findPetsByStatusRequest | findPetsByStatus Ens.Request |
| petshop.msg.findPetsByStatusResponse | findPetsByStatus Ens.Response |
| petshop.msg.findPetsByTagsRequest | indPetsByTags Ens.Request |
| petshop.msg.findPetsByTagsResponse | indPetsByTags Ens.Response |
| petshop.msg.getInventoryRequest | getInventory Ens.Request |
| petshop.msg.getOrderByIdRequest | getOrderById Ens.Request |
| petshop.msg.getOrderByIdResponse | etOrderById Ens.Response |
| petshop.msg.getPetByIdRequest | getPetById Ens.Request |
| petshop.msg.getPetByIdResponse | getPetById Ens.Response |
| petshop.msg.getUserByNameRequest | getUserByName Ens.Request |
| petshop.msg.getUserByNameResponse | getUserByName Ens.Response |
| petshop.msg.loginUserRequest | loginUser Ens.Request |
| petshop.msg.logoutUserRequest | logoutUser Ens.Request |
| petshop.msg.placeOrderRequest | placeOrder Ens.Request |
| petshop.msg.placeOrderResponse | placeOrder Ens.Response |
| petshop.msg.updatePetRequest | updatePet Ens.Request |
| petshop.msg.updatePetWithFormRequest | updatePetWithForm Ens.Request |
| petshop.msg.updateUserRequest | updateUser Ens.Request |
| petshop.msg.uploadFileRequest | uploadFile Ens.Request |
| petshop.msg.uploadFileResponse | ploadFile Ens.Response |
| petshop.rest.Projection | Projection to setting up Proxy REST application at compile time |
| petshop.rest.REST | Proxy REST application |
  
  
### Configure a production  

Open and start petshop.Production from [production page](http://localhost:52795/csp/irisapp/EnsPortal.ProductionConfig.zen).    
This is the auto generated production.  
<img width="1123" src="https://raw.githubusercontent.com/lscalese/OpenAPI-Client-Gen/master/assets/Production-Open-1.png">

<img width="1123" src="https://raw.githubusercontent.com/lscalese/OpenAPI-Client-Gen/master/assets/ProxyService-1.png">

Great!  Our production is ready.  
Let's push input data.

### Add Pet

The generated production include REST api provided for proxy usage.  
The rest class is petshop.REST for this sample.  
The web application is automatically configured at compile time (using a Projection).  

Since version 1.2.0, swagger specification is available for the generated proxy, ex :  `/petshoprest/_spec`  

To generate input data, we use curl command line.  

**Add a pet to Petstore :**  
```
curl --location --request POST 'http://localhost:52795/petshoprest/pet' \
--header 'Content-Type: application/json' \
--data-raw '{
  "category": {
    "id": 0,
    "name": "string"
  },
  "id" : 456789,
  "name": "Kitty_Galore",
  "photoUrls": [
    "string"
  ],
  "tags": [
    {
      "id": 0,
      "name": "string"
    }
  ],
  "status": "available"
}'
```

The production runs in async mode, so the rest proxy application does not wait for the response.  
Don't wait a body response.  
This behavior could be edited, but basically, Interoperability production uses async mode.  

**Edit : sync mode is used for proxy rest application since version 1.1.0+**

### Upload an image
```
curl --location --request POST 'http://localhost:52795/petshoprest/pet/456789/uploadImage' \
--form 'file=@/home/lorenzo/Pictures/call.jpg' \
--form 'additionalMetadata=tag1'
```
to adapt with your own image path.  

### Get By ID

```
curl --location --request GET 'http://localhost:52795/petshoprest/pet/456789'
```

### Find By Status

```
curl --location --request GET 'http://localhost:52795/petshoprest/pet/findByStatus?status=pending'
```

Important: Sometimes, there is invalid data on the server ... A parse error can occured due to a required  
field in the specification not returned by the server.  

### Delete pet

```
curl --location --request DELETE 'http://localhost:52795/petshoprest/pet/456789' \
--header 'Accept: application/json' \
--header 'api-key: special-key'
```

### Create User 
```
curl --location --request POST 'http://localhost:52795/petshoprest/user/createWithArray' \
--header 'Content-Type: application/json' \
--data-raw '[
  {
    "id": 14835440378,
    "username": "contest01",
    "firstName": "contest02",
    "lastName": "contest",
    "email": "string",
    "password": "string",
    "phone": "string",
    "userStatus": 0
  },
  {
    "id": 14835440379,
    "username": "contest02",
    "firstName": "contest02",
    "lastName": "contest02",
    "email": "string",
    "password": "string",
    "phone": "string",
    "userStatus": 0
  }
]'
```

### Get User by name

```
curl --location --request GET 'http://localhost:52795/petshoprest/user/contest02'
```

Now you can check your production and the message viewer.

<img width="1123" src="https://raw.githubusercontent.com/lscalese/OpenAPI-Client-Gen/master/assets/Production-MessageViewer-2.png">

Also you can analyze all messages with visual trace.  
<img width="1123" src="https://raw.githubusercontent.com/lscalese/OpenAPI-Client-Gen/master/assets/Visual-Trace-2.png">
<img width="1123" src="https://raw.githubusercontent.com/lscalese/OpenAPI-Client-Gen/master/assets/GetById.png">
<img width="1123" src="https://raw.githubusercontent.com/lscalese/OpenAPI-Client-Gen/master/assets/FindByStatus.png">



**SQL Query to show GenericResponse records :**
```
select ID, httpStatusCode, operation, operationStatusText, SUBSTRING(body,1)
from petshop.GenericResponse
order by id desc
```

### How It works

What happened when you add a pet with the curl command?  
In short : 

* The /petshoprest is invoked and create an instance of petshop.msg.addPetRequest (this is an Ens.Request subclass).  
* The rest process invoke Business Process (petshop.bp.Process) using petshop.bs.ProxyService.  
* petshop.bp.Process send the request to the Business Operation (petshop.bo.Operation).  
* petshop.bo.Operation create an http request related to the received Ens.Request instance and fill a petshop.GenericResponse.  
* petshop.bp.Process receive the response.  


## Code snippet

### Generate classes on local machine

By URL
```
Set sc = ##class(dc.openapi.client.Spec).generateApp("petshop", "https://petstore.swagger.io:443/v2/swagger.json")
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

### Generate classes for export code purpose only

```
TSTART
Set features("compile") = 0
Set sc = ##class(dc.openapi.client.Spec).%CreateClientApplication(appName, spec, .features)
Do $SYSTEM.OBJ.ExportPackageToStream(appName, .xmlStream)
TROLLBACK ; Code has been exported to xmlStream, a simple TROLLBACK delete all generated definition in code database.
```

## REST Api

A REST Api is also available for upload swagger specification document and download all generated classes to xml format.  
You can easily test it with swagger-ui tools:  

* Open swagger-ui : http://localhost:52795/swagger-ui/index.html
* Explore : http://localhost:52795/swaggerclientgen/api/_spec
* Select schemes http.  
* In the body parameter, put your swagger 2.0 on json format or an url to download the json file.
* Click execute and then download.  

<img width="1123" src="https://raw.githubusercontent.com/lscalese/OpenAPI-Client-Gen/master/assets/Swagger-ui-1.png">

Or use the basic embedded form at : http://localhost:52795/csp/swaggerclientgen/dc.openapi.client.api.cspdemo.cls

<img width="1123" src="https://raw.githubusercontent.com/lscalese/OpenAPI-Client-Gen/master/assets/basic-form.png">

## Prerequisites
Make sure you have [git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git) and [Docker desktop](https://www.docker.com/products/docker-desktop) installed.

## Installation: ZPM

Open IRIS Namespace with Interoperability Enabled.
Open Terminal and call:
```
zpm "install openapi-client-gen"
zpm "install objectscript-openapi-definition"
```

Optional swagger-ui: 
```
zpm "install swagger-ui"
```

## Installation: Docker
Clone/git pull the repo into any local directory

```
$ git clone https://github.com/lscalese/OpenAPI-Client-Gen.git
```

Open the terminal in this directory and run:

```
$ docker-compose build
```

3. Run the IRIS container with your project:

```
$ docker-compose up -d
```
