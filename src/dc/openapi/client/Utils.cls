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

}
