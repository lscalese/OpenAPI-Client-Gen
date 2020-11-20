Include Ensemble

Class dc.openapi.client.Utils
{

ClassMethod invokeHostAsync(targetHostName As %String, message As %Persistent, serviceName As %String = "EnsLib.Testing.Service", sessionId As %Integer = "") As %Status
{
    #dim sc As %Status
    
    #dim prod As Ens.Config.Production = ..getCurrentProduction()
    if '$isObject(prod) quit $$$ERROR($$$GeneralError, "Produciton is not running")
        
    #dim item As Ens.Config.Item = ..findConfigItem(targetHostName)
    if '$isObject(item) quit $$$ERROR($$$GeneralError, "Host " _ targetHostName _ " not found")
    
    #dim service As Ens.BusinessService
    set sc = ##class(Ens.Director).CreateBusinessService(serviceName, .service)
    if $$$ISERR(sc) quit sc
    
    if (sessionId '= "") set service.%SessionId = sessionId
    
    set sc = service.SendRequestAsync(targetHostName, message)
    
    quit sc
}

ClassMethod invokeHostSync(targetHostName As %String, message As %Persistent, serviceName As %String = "EnsLib.Testing.Service", sessionId As %Integer = "", pResponse As Ens.Response) As %Status
{
    #dim sc As %Status
    
    #dim prod As Ens.Config.Production = ..getCurrentProduction()
    if '$isObject(prod) quit $$$ERROR($$$GeneralError, "Produciton is not running")
        
    #dim item As Ens.Config.Item = ..findConfigItem(targetHostName)
    if '$isObject(item) quit $$$ERROR($$$GeneralError, "Host " _ targetHostName _ " not found")
    
    #dim service As Ens.BusinessService
    set sc = ##class(Ens.Director).CreateBusinessService(serviceName, .service)
    if $$$ISERR(sc) quit sc
    
    if (sessionId '= "") set service.%SessionId = sessionId
    
    set sc = service.SendRequestSync(targetHostName, message, .pResponse)

    quit sc
}

/// Get current production
ClassMethod getCurrentProduction() As Ens.Config.Production
{
    #dim sc As %Status
    #dim prodName As %String
    #dim prodState As %Integer
    
    // Get produciton name
    if '##class(Ens.Director).IsProductionRunning(.prodName) quit ""
    
    
    // Open produciton by name
    #dim prod As Ens.Config.Production = ##class(Ens.Config.Production).%OpenId(prodName, , .sc)
    if $$$ISERR(sc)
    {
        $$$LOGERROR($System.Status.GetErrorText(sc))
        quit ""
    }
    
    quit prod
}

/// Find host by name
ClassMethod findConfigItem(name As %String, businessType As %String = "", enabledOnly As %Boolean = 0) As Ens.Config.Item
{
    #dim sc As %Status
    
    // Get current production
    #dim prod As Ens.Config.Production = ..getCurrentProduction()
    if '$isObject(prod) quit ""

    // Search for our target
    #dim item As Ens.Config.Item
    #dim result As Ens.Config.Item = ""
    for i = prod.Items.Count():-1:1
    {
        set item = prod.Items.GetAt(i)
        
        if '$isObject(item) continue
        if ((businessType '= "") && (item.BusinessType() '= businessType)) || (item.Name '= name) || (enabledOnly && 'item.Enabled) continue
                        
        set result = item
        quit
    }
	Quit result
}

ClassMethod processParsedResponse(pHttpResponse As %Net.HttpResponse, responseClass As %String, caller As %String, pRequest As Ens.Request, pResponse As Ens.Response) As %Status
{
    Return:responseClass="" $$$OK
    Set parsedResponse = "", sc = $$$OK
    
    If (pHttpResponse.ContentType="application/json") {
        Set httpStatusCode = pHttpResponse.StatusCode
        
        Set parsedResponse = $ClassMethod(responseClass, "%New")
        
        Quit:parsedResponse.%GetParameter(httpStatusCode _ "MODEL")="" sc

        #define zIsList httpStatusCode _ "ISLIST"
        #define zModelType httpStatusCode _ "MODELTYPE"
        #define zModel httpStatusCode _ "MODEL"

        Try {
            If parsedResponse.%GetParameter( $$$zIsList ) {
                Set list = [].%FromJSON(pHttpResponse.Data)
                Set iter = list.%GetIterator()
                While iter.%GetNext(.keyParam, .value) {
                    Set model = $ClassMethod(parsedResponse.%GetParameter( $$$zModelType ), "%New")
                    Do model.%JSONImport(value)
                    Do $Method($Property(parsedResponse, parsedResponse.%GetParameter( $$$zModel )), "Insert", model)
                }
            } Else {
                Set model = $ClassMethod(parsedResponse.%GetParameter( $$$zModelType ), "%New")
                Do model.%JSONImport(pHttpResponse.Data)
                Set $Property(parsedResponse, parsedResponse.%GetParameter( $$$zModel )) = model
            }
            Set pResponse.parsedResponse = parsedResponse
        } Catch(ex) {
            Set sc = ex.AsStatus()
        }
    }

    Return sc
}

ClassMethod fillReponse(genericResponse) As %Status
{
    #dim %response As %CSP.Response
    Set %response.ContentType = genericResponse.headers.GetAt( "CONTENT-TYPE" )

    For header = "CONTENT-DISPOSITION" {
        Do:genericResponse.headers.GetAt( header )'="" %response.SetHeader( header, genericResponse.headers.GetAt( header ) )
    }

    Quit $$$OK
}

ClassMethod getSwaggerSpec(className As %String, xDataName As %String, webapp As %String, Output sc As %Status) As %DynamicObject
{
    set sc = $$$OK
    Set xDataTemplate = ##class(%Dictionary.CompiledXData).%OpenId(className _ "||" _ xDataName ,,.sc)
    Quit:$$$ISERR(sc) ""
    
    Try{

        Set swagger = {}.%FromJSON(xDataTemplate.Data)
        Set swagger.basePath = webapp
        Set:$Get(%request)'="" swagger.host = %request.CgiEnvs("SERVER_NAME") _ ":" _ %request.CgiEnvs("SERVER_PORT")
    
    } Catch (ex) {
    
        Set sc = ex.AsStatus()
    
    }

    Quit:$$$ISERR(sc) ""

    Quit swagger
}

}
