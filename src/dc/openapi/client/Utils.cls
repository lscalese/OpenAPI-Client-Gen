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

ClassMethod log(msg As %String, nl As %Boolean = {$$$YES}, dtOnNL As %Boolean = {$$$YES})
{
    Quit:$Get(%zverbose)=0

    Write:nl !
    Write:nl&&dtOnNL $ZDateTime($Horolog, 3, 1), " "
    Write msg

    Quit
}

}
