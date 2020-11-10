## OPENAPI Client Gen

This is an application to generate an Iris interoperability production from a Swagger 2.0 specification document.  
Instead of existing tools, this application generates client production.

It could be used as tool to create production on your local instance or to be hosted.  
If this application is hosted, a REST api is available to upload the specification document and download the generated classes.  

All generated classes are ABSOLUTELY NOT linked in any way with the generator.  
Your free to edit anything to adapt it with your need.  
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
The Ens.Response generated subclass is named "package.GenericResponse" (petshop.GenericResponse in this sample).  
It contains some properties to store the body response, headers, http status code, performed operation and status.  

* **Business Process class**  
The generated Business process name is simply packageName.Process (petshop.Process in this sample).  
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
| petshop.GenericResponse | Generic Ens.Response |
| petshop.Operation | Business Operation |
| petshop.Process | Business Process |
| petshop.Production | Production configuration |
| petshop.Projection | Projection to create CSP proxy Rest web application at compile time |
| petshop.ProxyService | Empty Business Service used by proxy web application |
| petshop.REST | %CSP.REST class for proxy web application |
| petshop.spec | Swagger specification used by the generator |
| petshop.Utils | utils... |
| petshop.addPetRequest | Ens.Request for addPet |
| petshop.addPetService | addPet Business Service template |
| petshop.createUserRequest | Ens.Request for createUser |
| petshop.createUserService | createUser Business Service template |
| petshop.createUsersWithArrayInputRequest | Ens.Request for createUsersWithArrayInput |
| petshop.createUsersWithArrayInputService | reateUsersWithArrayInput Business Service template |
| petshop.createUsersWithListInputRequest | Ens.Request for createUsersWithListInput |
| petshop.createUsersWithListInputService | createUsersWithListInput Business Service template |
| petshop.deleteOrderRequest | Ens.Request for deleteOrder |
| petshop.deleteOrderService | deleteOrder Business Service template|
| petshop.deletePetRequest | Ens.Request for deletePet |
| petshop.deletePetService | deletePet Business Service template|
| petshop.deleteUserRequest | Ens.Request for deleteUser |
| petshop.deleteUserService | deleteUser Business Service template |
| petshop.findPetsByStatusRequest | Ens.Request for findPetsByStatus |
| petshop.findPetsByStatusService | findPetsByStatus Business Service template |
| petshop.findPetsByTagsRequest | Ens.Request for findPetsByTags |
| petshop.findPetsByTagsService | findPetsByTags Business Service template |
| petshop.getInventoryRequest | Ens.Request for getInventory |
| petshop.getInventoryService | getInventory Business Service template |
| petshop.getOrderByIdRequest | Ens.Request for getOrderById |
| petshop.getOrderByIdService | getOrderById Business Service template |
| petshop.getPetByIdRequest | Ens.Request for getPetById |
| petshop.getPetByIdService | getPetById Business Service template|
| petshop.getUserByNameRequest | Ens.Request for getUserByName |
| petshop.getUserByNameService | getUserByName Business Service template|
| petshop.loginUserRequest | Ens.Request for loginUser |
| petshop.loginUserService | loginUser Business Service template |
| petshop.logoutUserRequest | Ens.Request for logoutUser |
| petshop.logoutUserService | logoutUser Business Service template |
| petshop.placeOrderRequest | Ens.Request for placeOrder |
| petshop.placeOrderService | placeOrder Business Service template |
| petshop.updatePetRequest | Ens.Request for updatePet |
| petshop.updatePetService | updatePet Business Service template |
| petshop.updatePetWithFormRequest | Ens.Request for updatePetWithForm |
| petshop.updatePetWithFormService | updatePetWithForm Business Service template |
| petshop.updateUserRequest | Ens.Request for updateUser |
| petshop.updateUserService | updateUser Business Service template |
| petshop.uploadFileRequest | Ens.Request for uploadFile |
| petshop.uploadFileService | uploadFile Business Service template |
  
  
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

### Upload an image
```
curl --location --request POST 'http://localhost:52795/petshoprest/pet/456789/uploadImage' \
--form 'file=@/home/lorenzo/Pictures/call.jpg' \
--form 'additionalMetadata=tag1'
```
to adapt with your own image path.  

### Delete pet

```
curl --location --request DELETE 'http://localhost:52795/petshoprest/pet/456789' \
--header 'Accept: application/json' \
--header 'api-key: special-key'
```

Now you can check your production and the message viewer.

<img width="1123" src="https://raw.githubusercontent.com/lscalese/OpenAPI-Client-Gen/master/assets/Production-MessageViewer-2.png">

Also you can analyze all messages with visual trace.  
<img width="1123" src="https://raw.githubusercontent.com/lscalese/OpenAPI-Client-Gen/master/assets/Visual-Trace-2.png">

**SQL Query to show GenericResponse records :**
```
select ID, httpStatusCode, operation, operationStatusText, SUBSTRING(body,1)
from petshop.GenericResponse
order by id desc
```

### How It works

What happened when you add a pet with the curl command?  
In short : 

* The /petshoprest is invoked and create an instance of petshop.addPetRequest (this is an Ens.Request subclass).  
* The rest process invoke Business Process (petshop.Process) using petshop.ProxyService.  
* petshop.Process send the request to the Business Operation (petshop.Operation).  
* petshop.Operation create an http request related to the received Ens.Request instance and fill a petshop.GenericResponse.  
* petshop.Process receive the response.  


## Code snippet

### Generate classes on local machine

By URL
```
Set sc = ##class(dc.openapi.client.Spec).generateApp("petshop", "https://petstore.swagger.io:443/v2/swagger.json")
```
By filename, ex:
```
Set sc = ##class(dc.openapi.client.Spec).generateApp("petshop", "/opt/irisapp/clientgen.json")
```
By DynamicObject

```
Set spec = {} ; Set your specficiation here
Set sc = ##class(dc.openapi.client.Spec).generateApp("petshop", spec)
```

### Generate classes for export code purpose only

```
TSTART
Set generator = ##class(dc.openapi.client.Generator).%New()
Set generator.spec = spec
Set generator.application = appName
Set generator.compile = 0
Set sc = generator.generate()
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
