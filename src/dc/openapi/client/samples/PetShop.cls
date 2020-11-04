Class dc.openapi.client.samples.PetShop
{

ClassMethod generatePetShopClient() As %Status
{
    Write !,"Generate application dc.openapi.client.petshop..."

    Set sc = ##class(dc.openapi.client.Spec).generateApp("petshop", "https://petstore.swagger.io:443/v2/swagger.json")
    
    Write "Status : ", $SYSTEM.Status.GetOneErrorText(sc)

    Return sc
}

ClassMethod addPet(petName As %String = {"kitty_"_$Random(1000)}) As %Status
{
    Set sc = $$$OK 
    Set entry = ##class(dc.openapi.client.samples.InputPet).%New()
    Set entry.petName = petName
    Set entry.categoryName = "Admin Cat"
    Set entry.categoryId = 99555
    
    Return entry.%Save()
}

/*
ClassMethod generateDocConverter() As %Status
{
    
    Write !,"Generate application dc.openapi.client.petshop..."
    s spec = {"swagger":"2.0","info":{"version":"0.2.0","title":"document-converter-box","description":"Document converter API","contact":{"name":"Lorenzo Scalese"}},"basePath":"/documentconverter/api","schemes":["http","https"],"consumes":["application/json","multipart/form-data"],"produces":["application/json","application/pdf","text/plain"],"security":[{"BasicAuth":[]}],"paths":{"/v1/ping":{"get":{"tags":["Test"],"summary":"Ping test service","description":"Ping test.","operationId":"Ping","produces":["application/json"],"responses":{"200":{"description":"pong","schema":{"type":"object","properties":{"Pong":{"type":"string"}}}}}}},"/v1/convert":{"post":{"tags":["Converter"],"summary":"Convert a file to another format.","description":"Convert a file to another format, ex: pdf, txt, docx, ...\r\n There is a lot of possible combination.","operationId":"Convert","consumes":["multipart/form-data"],"parameters":[{"in":"formData","name":"inputFile","required":true,"description":"file to convert","type":"file"}],"produces":["text/plain","application/pdf","application/vnd.openxmlformats-officedocument.wordprocessingml.document","application/msword","text/html","application/vnd.oasis.opendocument.presentation","application/vnd.oasis.opendocument.spreadsheet","application/vnd.oasis.opendocument.text","application/vnd.ms-powerpoint","application/vnd.openxmlformats-officedocument.presentationml.presentation","application/rtf","application/vnd.ms-excel","application/vnd.openxmlformats-officedocument.spreadsheetml.sheet","image/png","image/jpeg"],"responses":{"200":{"description":"Converted document"},"500":{"description":"Conversion error"}}}},"/v1/pdf/merge":{"post":{"tags":["Pdf"],"summary":"Merge up to 5 PDF files","produces":["application/pdf","text/plain"],"consumes":["multipart/form-data"],"operationId":"MergePDF","parameters":[{"in":"formData","name":"pdf1","required":true,"description":"file to merge","type":"file"},{"in":"formData","name":"pdf2","required":true,"description":"file to merge","type":"file"},{"in":"formData","name":"pdf3","required":false,"description":"file to merge","type":"file"},{"in":"formData","name":"pdf4","required":false,"description":"file to merge","type":"file"},{"in":"formData","name":"pdf5","required":false,"description":"file to merge","type":"file"}],"responses":{"200":{"description":"Converted document"}}}},"/v1/pdf/image/{page}":{"post":{"tags":["Pdf"],"summary":"Convert a pdf page to an image.","description":"Select a page number from a pdf and convert to an image.","produces":["image/png","image/jpeg"],"consumes":["multipart/form-data"],"operationId":"PdfToImg","parameters":[{"in":"formData","name":"pdf","required":true,"description":"PDF file","type":"file"},{"in":"path","name":"page","required":true,"description":"Page number to convert to an image.","type":"integer"}],"responses":{"200":{"description":"Image"}}}},"/v1/pdf/extract/{startPage}/{endPage}":{"post":{"tags":["Pdf"],"summary":"Extract one or more pages from a pdf file.","produces":["application/pdf","text/plain"],"consumes":["multipart/form-data"],"operationId":"PdfSplit","parameters":[{"in":"formData","name":"pdf","required":true,"description":"PDF file","type":"file"},{"in":"path","name":"startPage","required":true,"description":"Start page number to extract.","type":"integer"},{"in":"path","name":"endPage","required":true,"description":"End page number to extract.","type":"integer"}],"responses":{"200":{"description":"Extracted page(s)."}}}},"/v1/mimetypes":{"get":{"tags":["Utils"],"summary":"Return the list of known mime types.","description":"Return the list of known mime types by document converter and the associated file extension.","operationId":"MimeTypes","produces":["application/json"],"parameters":[{"in":"query","name":"jsfltsc","description":"Search Criteria example [\"extension\",\"pdf\",\"=\"]","required":false,"type":"string"},{"in":"query","name":"detail","description":"If set to 1, the service return an additional fields \"convert\" to specify all compatible conversion with service /v1/convert.","required":false,"type":"string"}],"responses":{"200":{"description":"List of mimetypes."}}},"post":{"tags":["Utils"],"summary":"Return the mimetypes of an uploaded file.  Can be useful for debugging.","description":"Return the mimetypes of an uploaded file.  Can be useful for debugging.","operationId":"FileMimeTypes","produces":["application/json"],"consumes":["multipart/form-data"],"parameters":[{"in":"formData","name":"inputFile","required":true,"description":"Processed file to find the mimetypes.","type":"file"}],"responses":{"200":{"description":"Mimetypes information for the uploaded file."}}}},"/v1/logs":{"get":{"tags":["Utils"],"summary":"User operation logs.","description":"User operation logs for convert and pdf operations.","produces":["application/json"],"operationId":"UserLogs","parameters":[{"in":"query","name":"jsfltsc","description":"Search Criteria example [\"property\",\"value\",\"=\"]","required":false,"type":"string"},{"in":"query","name":"jsflt","description":"Search Criteria example: message,status","required":false,"type":"string"},{"in":"query","name":"jsfltsrt","description":"Sort by example name.first,desc or name.first,asc.\r\nIf sort order is ommited desc is selected by default.\r\nApplicable only if the response is an Array.\r\nIf the response is not an array the limit parameter is ignored.","required":false,"type":"string"},{"in":"query","name":"jsfltlmt","description":"Maximum number of records to return.\r\nApplicable only if the response is an Array.\r\nApplicable only if the response is an Array.\r\nIf the response is not an array the limit parameter is ignored.","required":false,"type":"integer"}],"responses":{"200":{"description":"logs...","schema":{"type":"object","properties":{"logs":{"type":"array","items":{"type":"object","properties":{"dateTime":{"type":"string"},"userName":{"type":"string"},"operation":{"type":"string"},"status":{"type":"string"},"additionalInfo":{"type":"string"}}}}}}}}}},"/v1/_spec":{"get":{"tags":["Developers"],"summary":"OpenAPI spec 2.0","description":"OpenAPI spec 2.0 .\n","produces":["application/json"],"operationId":"SwaggerSpec","parameters":[],"responses":{"200":{"description":"..."}}}}},"securityDefinitions":{"BasicAuth":{"type":"basic"}},"host":"www.lscalese.ovh:443"}
    Set sc = ##class(dc.openapi.client.Spec).generateApp("docconverter", .spec)
    
    Write "Status : ", $SYSTEM.Status.GetOneErrorText(sc)

    Return sc
}

ClassMethod addPet(petName As %String = {"kitty_"_$Random(1000)}) As dc.openapi.client.Response
{
    Set sc = $$$OK, rsp = ""

    Write !,"** Call /pet service (post method) to create a pet"

    Try { 
        ;Set petId = $Tr($Zdt($h,3,1),"-: ")
        ;"id": (petId),
            
        Set body = {
            "category": {
                "id": 99555,
                "name": "Admin Cat"
            },
            "name": (petName),
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

        Write !, "Attempt to create ", petName
        
        Set cli = ##class(dc.openapi.client.petshop.client).%New()
        Set cli.protocol="https"
        Set cli.SSLConfiguration = "default"
        Set accept = "application/json"
        Set consume = "application/json"
        Set rsp = cli.addPet(accept, consume, body)
        
        Write !, "Response httpStatusCode : ",rsp.httpStatusCode
        
        If rsp.httpStatusCode = 200 {
            Write !, "Status : ", rsp.statusText
            Write !,!, "Response Data : "
            
            Set jsFormater = ##class(%JSON.Formatter).%New()
            Set jsRsp = rsp.getDynamicObject()
            Do jsFormater.Format(jsRsp)

            Write !,!, "Pet ID : ",jsRsp.id
        }

    }  Catch (ex) {
        Set sc = ex.AsStatus()
        Write !,"An error occured :", $SYSTEM.Status.GetOneErrorText(sc)
    }

    Return rsp
}

/// If you already add a pet<br/>
/// You can get a previous created pet by ID <br/>
ClassMethod getPet(petId As %String) As dc.openapi.client.Response
{
    Set sc = $$$OK, rsp = ""

    Write !,"** Call /pet/? service (get method) to get an existing pet by id"

    Try { 
        Set cli = ##class(dc.openapi.client.petshop.client).%New()
        Set cli.protocol="https"
        Set cli.SSLConfiguration = "default"
       
        Set accept = "application/json"
        Set consume = "application/json"
        
        Set rsp = cli.getPetById(accept, consume, petId)

        Write !, "Response httpStatusCode : ",rsp.httpStatusCode

        If rsp.httpStatusCode = 200 {
            Write !, "Status : ", rsp.statusText
            Write !,!, "Response Data : "
            
            Set jsFormater = ##class(%JSON.Formatter).%New()
            Set jsRsp = rsp.getDynamicObject()
            Do jsFormater.Format(jsRsp)

        }


    }  Catch (ex) {
        Set sc = ex.AsStatus()
        Write !,"An error occured :", $SYSTEM.Status.GetOneErrorText(sc)
    }

    Return rsp
}*/
}
