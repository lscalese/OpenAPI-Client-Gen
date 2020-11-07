## OPENAPI Client Gen

This is an application to generate Iris interoperability production from a Swagger 2.0 specification document.  
It can be used as tool to create classes on your local instance or to be hosted.  
If this application is hosted, a REST api is available to upload the specification document and download the generated classes.  
  
  
## Production Sample

In this sample we generate a production for [petshop Swagger 2.0 API](https://petstore.swagger.io/) REST Api  
from the [specification 2.0](https://petstore.swagger.io/v2/swagger.json).  
After that we prepare the BusinessService class from a generated template, generate input data and observes the result.  

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
The generated classes are templates which should be edited with your need.  In this sample we edit petshop.addPetService at the next step.  

* **Ens.Request classes**  
For each request defined, an Ens.Request class is generated suffixed by "Request".  
This class represent all of parameters (query parameters, path, body, headers).  
The Business operation will consume an instance of this class to generate http request.  

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

### Prepare the BusinessService class

Export class petshop.addPetService to your projet.  

<img width="1123" src="https://raw.githubusercontent.com/lscalese/OpenAPI-Client-Gen/master/assets/PetShop-ExportClasses.png">

Edit the petshop.addPetService class to use our [dc.openapi.client.samples.InboundAdapter](https://github.com/lscalese/OpenAPI-Client-Gen/blob/master/src/dc/openapi/client/samples/InboundAdapter.cls#L1) ready for our sample.  

Replace : 
```
/// Auto generated : Change by your Adapter type.
Parameter ADAPTER = "Ens.Adapter";

/// Auto generated : Change by your Adapter type.
Property Adapter As Ens.Adapter;

```

By:
```
Parameter ADAPTER = "dc.openapi.client.samples.InboundAdapter";

Property Adapter As dc.openapi.client.samples.InboundAdapter;
```

After that, we implement the OnProcessInput method.  
```
Method OnProcessInput(pInput As dc.openapi.client.samples.InputPet, pOutput As %RegisteredObject) As %Status
{
	Set msg = ##class(petshop.addPetRequest).%New()
	Set msg.accept = "application/json"
	Set msg.consume = "application/json"
	Set body = {
		"category": {
			"id": (pInput.categoryId),
			"name": (pInput.categoryName)
		},
		"name": (pInput.petName),
		"photoUrls": [
			"https://blog.nordnet.com/wp-content/uploads/2018/08/lolcat-working-problem.png"
		],
		"tags": [
			{
			"id": 0,
			"name": "string"
			}
		],
		"status": "available"
	}
	Do msg.bodybody.Write(body.%ToJSON()) ; To implement
	Return ..SendRequestAsync("petshop.Process", msg)
}
```

### Configure a production

Open the [production page](http://localhost:52795/csp/irisapp/EnsPortal.ProductionConfig.zen) and open petshop.Production.  
This is an auto generated production.  
<img width="1123" src="https://raw.githubusercontent.com/lscalese/OpenAPI-Client-Gen/master/assets/Production-Open.png">

Enable petshop.addPetService .  
<img width="1123" src="https://raw.githubusercontent.com/lscalese/OpenAPI-Client-Gen/master/assets/PetService-Enabled.png">

Apply and start the production.  

Great!  Our production is ready.  
Let's create data.

### Create Pet

To generate input data, call this method in a terminal:

```
Do ##class(dc.openapi.client.samples.PetShop).addPet()
```

Now you can check your production and the message viewer.

<img width="1123" src="https://raw.githubusercontent.com/lscalese/OpenAPI-Client-Gen/master/assets/Production-MessageViewer.png">

Also you can analyze all messages with visual trace.  
<img width="1123" src="https://raw.githubusercontent.com/lscalese/OpenAPI-Client-Gen/master/assets/Visual-Trace.png">

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

<img width="1123" src="https://raw.githubusercontent.com/lscalese/OpenAPI-Client-Gen/master/assets/Swagger-ui-1.png">

* click execute and then download

<img width="1123" src="https://raw.githubusercontent.com/lscalese/OpenAPI-Client-Gen/master/assets/Swagger-ui-2.png">

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
