Class dc.openapi.client.samples.PetShop
{

ClassMethod generatePetShopClient() As %Status
{
    Set applicationName = "petshop"
    Write !,"Delete previous code generation ..."

    Do $SYSTEM.OBJ.DeletePackage(applicationName)

     Write !,"Generate client app "_applicationName _"..."


    Set sc = ##class(dc.openapi.client.Spec).generateApp(applicationName, "https://petstore3.swagger.io/api/v3/openapi.json")
    
    Write "Status : ", $SYSTEM.Status.GetOneErrorText(sc)

    Write !,"Compile ..."

    Set sc = $$$ADDSC(sc, $SYSTEM.OBJ.CompilePackage(applicationName))
    Return sc
}

ClassMethod addPet() As %Status
{
    Set sc = $$$OK
    Set messageRequest = ##class(petshop.requests.addPet).%New()
    Set messageRequest.%ContentType = "application/json"
    
    Set messageRequest.body1 = ##class(petshop.model.Pet).%New()
    Do messageRequest.body1.%JSONImport({"id":123,"name":"Kitty Galore","photoUrls":["https://www.tippett.com/wp-content/uploads/2017/01/ca2DC049.130.1264.jpg"],"status":"pending"})
    
    Set sc = ##class(petshop.Utils).invokeHostSync("petshop.bp.SyncProcess", messageRequest, "petshop.bs.ProxyService", , .pResponse)
    
    If $$$ISERR(sc) Do $SYSTEM.Status.DisplayError(sc)
    
    Return sc
}

ClassMethod addPetSimpleClient() As %Status
{
    Set sc = $$$OK
    Set messageRequest = ##class(petshop.requests.addPet).%New(), messageRequest.body1 = ##class(petshop.model.Pet).%New()
    Set messageRequest.%ContentType = "application/json"
    Do messageRequest.body1.%JSONImport({"id":123,"name":"Kitty Galore","photoUrls":["https://localhost/img.png"],"status":"pending"})
    Set httpClient = ##class(petshop.HttpClient).%New("https://petstore3.swagger.io/api/v3","DefaultSSL")
    Set sc = httpClient.addPet(messageRequest, .messageResponse)
    If $$$ISERR(sc) Do $SYSTEM.Status.DisplayError(sc) Quit sc
    Write !,"Http Status code : ", messageResponse.httpStatusCode,!
    Do messageResponse.Pet.%JSONExport()
    Return sc
}

ClassMethod findPetsByStatus(status As %String = "availalbe") As %Status
{
    /// Exemple using interoperability framework
    
    Set ensRequest = ##class(petshop.requests.findPetsByStatus).%New()
    Set ensRequest.%Consume = "application/json"
    Set ensRequest.querystatus = "available"
    Set sc = ##class(petshop.Utils).invokeHostSync("petshop.bp.SyncProcess", ensRequest, "petshop.bs.ProxyService", , .pResponse)
    
    If $$$ISERR(sc) {
        Do $SYSTEM.Status.DisplayError(sc)
        Quit sc
    }

    If $IsObject(pResponse), pResponse.httpStatusCode = 200 {
        Do ##class(%JSON.Formatter).%New().Format(pResponse.body)
        ; pet list are also serialized in pResponse.ListOfPet property
        Write !,"List of pet name"
        
        Set key = ""
        For  {
            Set pet = pResponse.ListOfPet.GetNext(.key)
            Quit:key=""
            Write !," - ",pet.name
        }
    }

    Quit sc
}

ClassMethod findPetUsingHttpClient(status As %String = "availalbe") As %Status
{
    
    Set httpClient = ##class(petshop.HttpClient).%New()
    Set messageRequest = ##class(petshop.requests.findPetsByStatus).%New()
    Set messageRequest.%Consume = "application/json"
    Set messageRequest.querystatus = "available"
    Set sc = httpClient.findPetsByStatus(messageRequest, .messageResponse)
    If 'sc Do $SYSTEM.Status.DisplayError(sc)

    If $IsObject(messageResponse), messageResponse.httpStatusCode = 200 {
        Do ##class(%JSON.Formatter).%New().Format(messageResponse.body)
        ; pet list are also serialized in pResponse.ListOfPet property
        Write !,"List of pet name"
        
        Set key = ""
        For  {
            Set pet = messageResponse.ListOfPet.GetNext(.key)
            Quit:key=""
            Write !," - ",pet.name
        }
    }

    Quit sc
}

}
