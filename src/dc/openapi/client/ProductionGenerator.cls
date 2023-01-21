Include dc.openapi.client.macro

Class dc.openapi.client.ProductionGenerator Extends %RegisteredObject
{

Parameter PKGSERVICES = "bs";

Parameter PKGOPERATION = "bo";

Parameter PKGPROCESS = "bp";

Property spec As %DynamicObject;

Property application As %String;

Property productionClassName As %String [ InitialExpression = "Production" ];

Property tmp As %Binary [ MultiDimensional ];

ClassMethod zTest()
{
    ; zw ##class(dc.openapi.client.ProductionGenerator).zTest()
    ; do $SYSTEM.OBJ.CompileAll("ztestclient")

    Do $SYSTEM.OBJ.DeletePackage("ztestclient")

    TStart
    Set specification = {}.%FromJSON(##class(%Dictionary.CompiledXData).%OpenId("petshop.model.spec||OpenAPI").Data)
    Set generator = ##class(dc.openapi.client.ProductionGenerator).%New(specification, "ztestclient")
    Quit generator.Generate()
}

ClassMethod testf()
{
    /*
    Set ensRequest = ##class(ztestclient.requests.getPetById).%New()
    Set ensRequest.%Consume = "application/json"
    Set ensRequest.pathpetId=1
    ;Set pResponse = ##class(ztestclient.responses.getPetById).%New()
    Set sc = ##class(ztestclient.Utils).invokeHostSync("ztestclient.bp.SyncProcess", ensRequest, "ztestclient.bs.ProxyService", , .pResponse)
    q pResponse
    */

    Set ensRequest = ##class(ztestclient.requests.findPetsByStatus).%New()
    Set ensRequest.%Consume = "application/json"
    Set ensRequest.querystatus = "available"
    Set sc = ##class(ztestclient.Utils).invokeHostSync("ztestclient.bp.SyncProcess", ensRequest, "ztestclient.bs.ProxyService", , .pResponse)
    q pResponse
    zw sc
    q
}

Method %OnNew(specification As %DynamicObject, application As %String) As %Status
{
    Set ..spec = specification
    Set ..application = application
    Quit $$$OK
}

Method Generate() As %Status
{
    Set sc = $$$OK
    
    Set httpClientGenerator = ##class(dc.openapi.client.HttpClientGenerator).%New(..spec, ..application)
    Set httpClientGenerator.superRequest = "Ens.Request"
    Set httpClientGenerator.superResponse = ..application _ "." _..PackageResponse() _  ".GenericResponse" ;",Ens.Response"
    Set httpClientGenerator.superModel = "%Persistent,%JSON.Adaptor,%XML.Adaptor"
    Set httpClientGenerator.superGenericResponse = "%Persistent,Ens.Response"

    Set sc = $$$ADDSC(sc, httpClientGenerator.GenerateClient())

    ; Generate Business services
    Set sc = $$$ADDSC(sc, ..IterateOnOperation("GenerateBusinessService"))

    ; Generate Business process
    Set sc = $$$ADDSC(sc, ..GenerateBusinessProcess())

    ; Generate Business Operation
    Set sc = $$$ADDSC(sc, ..GenerateBusinessOperation())

    ; Generate Proxy service
    Set sc = $$$ADDSC(sc, ..GenerateProxyService())

    Set utilsClass =..application_".Utils"

    If '$$$defClassDefined(utilsClass) {    ;copy utils class to the target package
    
        Merge ^oddDEF(utilsClass) = ^oddDEF("dc.openapi.client.Utils")
        Set ^oddDEF(utilsClass, 1) = utilsClass
        ; class copy, explicit compile is needed
        $$$QuitOnError($SYSTEM.OBJ.Compile(utilsClass, "ck-d"))
    }

    ; Generate Production
    Set sc = $$$ADDSC(sc, ..GenerateProduction())
    
    Set sc = $$$ADDSC(sc, ..GenerateMessageMap())

    ; Force model with MAXLEN = ""
    Set sc = $$$ADDSC(sc, ..ForceNotDefinedMAXLEN( ..application _ ".model"))

    Quit sc
}

Method GenerateBusinessService(path As %String, pathItem As %DynamicObject, method As %String, operation As %DynamicObject) As %Status
{
    Set sc = $$$OK
    
    $$$zlog("* Generate Request class for " _path _ " "_ method _ "...")

    Do ##class(dc.openapi.client.HttpClientGenerator).CheckAndGenerateOperationId(method, .operation, path)
    Set className = ..application _"." _ ..#PKGSERVICES _ "." _ $$$zNormalizeClassName(operation.operationId)
    $$$zlog($Char(9) _"Class name is " _ className)


    #dim classDef As %Dictionary.ClassDefinition
    $$$QuitOnError(##class(Grongier.OpenApi.DefinitionV3).CreateClassDefInstance(className, .classDef))
    Set classDef.Super = "Ens.BusinessService"


    #dim property As %Dictionary.PropertyDefinition = ##class(%Dictionary.PropertyDefinition).%New()

    Set property.Name = "Adapter"
    Set property.Type = "Ens.Adapter"
    Set property.Description = "Auto generated : Change by your Adapter type."
    Do classDef.Properties.Insert(property)

    #dim classParameter As %Dictionary.ParameterDefinition = ##class(%Dictionary.ParameterDefinition).%New()
    Set classParameter.Name = "ADAPTER"
    Set classParameter.Default = "Ens.Adapter"
    Set classParameter.Description = "Auto generated : Change by your Adapter type."
    Do classDef.Parameters.Insert(classParameter)

    #dim mDef As %Dictionary.MethodDefinition = ##class(%Dictionary.MethodDefinition).%New()

    Set mDef.Name = "OnProcessInput"
    Set mDef.Description = "Auto generated method"
    Set mDef.FormalSpec = "pInput:%RegisteredObject,pOutput:%RegisteredObject"
    Set mDef.ReturnType = "%Status"

    Set msgRequestClass = ..application _"." _..PackageRequest() _ "." _ $$$zNormalizeClassName(operation.operationId)
    
    Do mDef.Implementation.WriteLine($Char(9) _ "Set sc = $$$OK" )
    Do mDef.Implementation.WriteLine($Char(9) _ "Set msg = ##class(" _ msgRequestClass _ ").%New()")
    Do mDef.Implementation.WriteLine($Char(9) _ "; Auto generated, put your own code...")
    Do mDef.Implementation.WriteLine($Char(9) _ "Return ..SendRequestAsync("""_ ..application _"." _..#PKGPROCESS_".Process" _ """, msg)")
    
    Do classDef.Methods.Insert(mDef)

    Set sc = classDef.%Save()
    Quit sc
}

ClassMethod PackageModel() As %String [ CodeMode = expression ]
{
##class(dc.openapi.client.HttpClientGenerator).%GetParameter("PKGMODEL")
}

ClassMethod PackageRequest() As %String [ CodeMode = expression ]
{
##class(dc.openapi.client.HttpClientGenerator).%GetParameter("PKGREQUEST")
}

ClassMethod PackageResponse() As %String [ CodeMode = expression ]
{
##class(dc.openapi.client.HttpClientGenerator).%GetParameter("PKGRESPONSE")
}

/// Helper to iterate operation object<br/>
/// the callback must be method with the parameters<br/>
/// (path As %String, pathItem As %DynamicObject, method As %String, operation As %DynamicObject)<br/>
Method IterateOnOperation(callBackMethod As %String) As %Status [ Private ]
{
    Set sc = $$$OK

    Quit:'..spec.%IsDefined("paths") sc

    Set pathIterator = ..spec.paths.%GetIterator()

    While pathIterator.%GetNext(.path, .pathItem) {
        
        Continue:'$IsObject(pathItem)

        For method = "get", "put", "post", "delete", "options", "head", "patch", "trace" {
            
            Set operation = pathItem.%Get(method)
            Continue:'$IsObject(operation)
            
            Set sc = $$$ADDSC(sc, $METHOD(##this, callBackMethod, path, pathItem, method, operation) )

        }

    }

    Quit sc
}

/// Generate Generic Business Process classes<br/>
Method GenerateBusinessProcess() As %Status
{
    #dim sc As %Status = $$$OK
    
    Set ensOperationClassName = ..application _"." _ ..#PKGOPERATION _ ".Operation"

    Set className = ..application _"." _ ..#PKGPROCESS _ ".Process"
    #dim cDef As %Dictionary.ClassDefinition
    $$$QuitOnError(##class(Grongier.OpenApi.DefinitionV3).CreateClassDefInstance(className, .cDef))
    Set cDef.Super = "Ens.BusinessProcess"
    $$$zlog("* Generate BusinessProcess class " _ className _" ...")

    Set mDef = ##class(%Dictionary.MethodDefinition).%New()
    Set mDef.Name = "OnRequest"
    Set mDef.FormalSpec = $$$FormatText("pRequest:%1,pResponse:%2", "Ens.Request", "Ens.Response")
    Set mDef.ReturnType = "%Status"
    Do mDef.Implementation.WriteLine($Char(9) _$$$FormatText("Return ..SendRequestAsync(""%1"", pRequest, 1, pRequest.%ClassName(1))", ensOperationClassName))
    Do cDef.Methods.Insert(mDef)

    Set mDef = ##class(%Dictionary.MethodDefinition).%New()
    Set mDef.Name = "OnResponse"
    Set mDef.FormalSpec = "request:%Library.Persistent,response:%Library.Persistent,callrequest:%Library.Persistent,callresponse:%Library.Persistent,pCompletionKey:%String"
    Set mDef.ReturnType = "%Status"
    Do mDef.Implementation.WriteLine($Char(9) _"Return $$$OK")
    Do cDef.Methods.Insert(mDef)

    Set sc = $$$ADDSC(sc, cDef.%Save())
    /// Sync process ...
   
    Set className = ..application _"." _ ..#PKGPROCESS _ ".SyncProcess"
    $$$QuitOnError(##class(Grongier.OpenApi.DefinitionV3).CreateClassDefInstance(className, .cDef))
    Set cDef.Super = "Ens.BusinessProcess"
    $$$zlog("* Generate BusinessProcess class " _ className _" ...")

    Set mDef = ##class(%Dictionary.MethodDefinition).%New()
    Set mDef.Name = "OnRequest"
    Set mDef.FormalSpec = $$$FormatText("pRequest:%1,pResponse:%2", "Ens.Request", "Ens.Response")
    Set mDef.ReturnType = "%Status"
    Do mDef.Implementation.WriteLine($Char(9) _$$$FormatText("Return ..SendRequestSync(""%1"", pRequest, .pResponse, ,pRequest.%ClassName(1))", ensOperationClassName))
    Do cDef.Methods.Insert(mDef)

    Set mDef = ##class(%Dictionary.MethodDefinition).%New()
    Set mDef.Name = "OnResponse"
    Set mDef.FormalSpec = "request:%Library.Persistent,response:%Library.Persistent,callrequest:%Library.Persistent,callresponse:%Library.Persistent,pCompletionKey:%String"
    Set mDef.ReturnType = "%Status"
    Do mDef.Implementation.WriteLine($Char(9) _"Return $$$OK")
    Do cDef.Methods.Insert(mDef)

    Set sc = $$$ADDSC(sc, cDef.%Save())

    Return sc
}

Method GenerateBusinessOperation() As %Status
{
    #dim sc As %Status = $$$OK
    
    Set ensOperationClassName = ..application _"." _ ..#PKGOPERATION _ ".Operation"    

    Set className = ensOperationClassName
    #dim cDef As %Dictionary.ClassDefinition
    $$$QuitOnError(##class(Grongier.OpenApi.DefinitionV3).CreateClassDefInstance(className, .cDef))
    Set cDef.Super = "Ens.BusinessOperation"
    $$$zlog("* Generate BusinessOperation class " _ className _" ...")

    #dim property As %Dictionary.PropertyDefinition = ##class(%Dictionary.PropertyDefinition).%New()
    Set property.Name = "Adapter"
    Set property.Type = "EnsLib.HTTP.OutboundAdapter"
    Do cDef.Properties.Insert(property)

    #dim classParameter As %Dictionary.ParameterDefinition = ##class(%Dictionary.ParameterDefinition).%New()
    Set classParameter.Name = "ADAPTER"
    Set classParameter.Default = "EnsLib.HTTP.OutboundAdapter"
    Do cDef.Parameters.Insert(classParameter)

    Set sc = cDef.%Save()

    Set sc = $$$ADDSC(sc, ..IterateOnOperation("GenerateMethodExecutor"))

    /*
    Set mDef = ##class(%Dictionary.MethodDefinition).%New()
    Set mDef.Name = "genericProcessResponse"
    Set mDef.FormalSpec = $$$FormatText("pRequest:%1,pResponse:%2,caller:%String,status:%Status,pHttpResponse:%Net.HttpResponse,parsedResponseClassName:%String", "Ens.Request", ..ensGenericResponseClassName)
    Set mDef.ReturnType = "%Status"
    Do ..genericResponseImpl(mDef) 
    Do cDef.Methods.Insert(mDef)

    
    Set mDef = ##class(%Dictionary.MethodDefinition).%New()
    Set mDef.Name = "GetRequest"
    Set mDef.FormalSpec = $$$FormatText("pRequest:%1","Ens.Request")
    Set mDef.ReturnType = "%Net.HttpRequest"

    Do mDef.Implementation.WriteLine($Char(9) _"#dim pHttpRequestIn As %Net.HttpRequest = ##class(%Net.HttpRequest).%New()")
    Do mDef.Implementation.WriteLine($Char(9) _"Do:##class(%Dictionary.CompiledProperty).%ExistsId(pRequest.%ClassName(1)_""||accept"") pHttpRequestIn.SetHeader(""accept"", pRequest.accept)")
    Do mDef.Implementation.WriteLine($Char(9) _"Return pHttpRequestIn")
    Do cDef.Methods.Insert(mDef)
    */
    

	Return sc
}

Method GenerateMethodExecutor(path As %String, pathItem As %DynamicObject, method As %String, operation As %DynamicObject) As %Status
{
    Set sc = $$$OK

    Set ensOperationClassName = ..application _"." _ ..#PKGOPERATION _ ".Operation"    
    Set requestClass = ..application _"." _ ..PackageRequest() _ "." _ $$$zNormalizeClassName(operation.operationId)
    Set responseClass = ..application _"." _ ..PackageResponse()_ "."  _ $$$zNormalizeClassName(operation.operationId)

    Set ..tmp("MessageMap","MessageType", requestClass) = $$$zNormalizeClassName(operation.operationId)


    Set classDef = ##class(%Dictionary.ClassDefinition).%OpenId(ensOperationClassName,, .sc)

    If $$$ISERR(sc) {
        $$$zlog("!cannot add executor method " _ ensOperationClassName _ " does not exist.")
        Quit sc
    }

    $$$zlog("+ Add method " _ operation.operationId _ " to " _ ensOperationClassName)

    Set methodDef = ##class(%Dictionary.MethodDefinition).%New()
    Set methodDef.Description = "Implement operationId : " _ operation.operationId
        _ $Char(13,10) _ method _ " " _path
    Set methodDef.Name = $$$zNormalizeClassName(operation.operationId)
    Set methodDef.FormalSpec = "requestMessage:" _ requestClass _ ",*responseMessage:" 
        _ responseClass

    Set methodDef.ReturnType = "%Status"
    Do methodDef.Implementation.WriteLine( $Char(9) _ "Set sc = $$$OK, pHttpRequestIn = ##class(%Net.HttpRequest).%New(), responseMessage = ##class("_responseClass_").%New()")
    Do methodDef.Implementation.WriteLine( $Char(9) _ "$$$QuitOnError(requestMessage.LoadHttpRequestObject(pHttpRequestIn))" )
    Do methodDef.Implementation.WriteLine( $Char(9) _ "$$$QuitOnError(..Adapter.SendFormDataArray(.pHttpResponse, """_method_""", pHttpRequestIn, , , ..Adapter.URL_requestMessage.%URL))")
    Do methodDef.Implementation.WriteLine( $Char(9) _ "$$$QuitOnError(responseMessage.LoadFromResponse(pHttpResponse, """_operation.operationId_"""))")
    Do methodDef.Implementation.WriteLine( $Char(9) _ "Quit sc")
    Do classDef.Methods.Insert(methodDef)

    Quit classDef.%Save()
}

Method GenerateProxyService() As %Status
{
    #dim className As %String = ..application _ "." _ ..#PKGSERVICES _ ".ProxyService"
    #dim classDef As %Dictionary.ClassDefinition
    $$$QuitOnError(##class(Grongier.OpenApi.DefinitionV3).CreateClassDefInstance(className, .classDef))
    Set classDef.Super = "Ens.BusinessService"
    Set classDef.ProcedureBlock = $$$YES
    Quit classDef.%Save()
}

Method GenerateProduction() As %Status
{
    Set sc = $$$OK
    Set productionClassName = ..application_".Production"

    #dim classDef As %Dictionary.ClassDefinition
    $$$QuitOnError(##class(Grongier.OpenApi.DefinitionV3).CreateClassDefInstance(productionClassName, .classDef))
    Set classDef.Super = "Ens.BusinessService"

    Set strServiceTemplate = "<Item Name=""{className}"" Category="""" ClassName=""{className}"" PoolSize=""1"" Enabled=""{enabled}"" Foreground=""false"" Comment="""" LogTraceEvents=""false"" Schedule=""""></Item>"

    Set (startKey, className, ensProxyServiceClassName) = ..application _ "." _ ..#PKGSERVICES _ ".", 
        ensProxyServiceClassName = ensProxyServiceClassName _"ProxyService"
    
    For  {
        Set className = $Order(^oddDEF(className))
        Quit:$Extract(className, 1, $LENGTH(startKey))'=startKey

        Set enabled = $Select(className = ensProxyServiceClassName: "true", 1: "false")
        Set service($Increment(service)) = $Replace($Replace(strServiceTemplate, "{className}", className), "{enabled}", enabled)
    }
    
    Set xData=##class(%Dictionary.XDataDefinition).%New()
    Set xData.Name = "ProductionDefinition"
    
    Set xDataTemplate = ##class(%Dictionary.XDataDefinition).%OpenId(..%ClassName(1)_"||ProductionDefinitionTemplate",,.sc)
    Return:$$$ISERR(sc) sc

    Set ensOperationClassName = ..application _"." _ ..#PKGOPERATION _ ".Operation"
    Set ensProcessClassName = ..application _"." _ ..#PKGPROCESS _ ".Process"
    Set ensProcessSyncClassName = ..application _"." _ ..#PKGPROCESS _ ".SyncProcess"

    Set server = $Select(..spec.%IsDefined("servers")&&$IsObject(..spec.servers.%Get(0)): ..spec.servers.%Get(0).url, 1:"")
    If server '= "" {
        Do ##class(%Net.URLParser).Decompose(server, .components)
    }

    While 'xDataTemplate.Data.AtEnd {
        Set line = xDataTemplate.Data.ReadLine()
        If line [ "{services}" {
            Set key = ""
            For  {
                Set key = $Order(service(key), 1, serviceStr)
                Quit:key=""
                Do xData.Data.WriteLine("  "_serviceStr)
            }
        } Else {
            Set line = $Replace(line, "{application}", ..application)
            Set line = $Replace(line, "{ensOperationClassName}", ensOperationClassName)
            Set line = $Replace(line, "{ensProcessClassName}", ensProcessClassName)
            Set line = $Replace(line, "{ensProcessSyncClassName}", ensProcessSyncClassName)
            Set line = $Replace(line, "{server}", $Get(components("host")))
            Set line = $Replace(line, "{port}", $Get(components("port")))
            Set line = $Replace(line, "{SSLConfig}", "DefaultSSL")
            Set line = $Replace(line, "{URL}", $Get(components("path")))
            
            Do xData.Data.WriteLine(line)
        }
    }

    Set cDef = ##class(%Dictionary.ClassDefinition).%New(productionClassName)
    Set cDef.ProcedureBlock = $$$YES
    Set cDef.Super = "Ens.Production"
    Do cDef.XDatas.Insert(xData)

    $$$QuitOnError(cDef.%Save())

    Return sc
}

/// Generate Message Map XDATA for Business Operation class<br/>
Method GenerateMessageMap() As %Status [ Private ]
{

    Set ensOperationClassName = ..application _"." _ ..#PKGOPERATION _ ".Operation"

    #dim cDef As %Dictionary.ClassDefinition = ##class(%Dictionary.ClassDefinition).%OpenId(ensOperationClassName,,.sc)

    Quit:$$$ISERR(sc) sc
    
    Do ##class(dc.openapi.client.Spec).%RemoveXDataBlock(cDef, "MessageMap")

    Set xData=##class(%Dictionary.XDataDefinition).%New()
    Set xData.Name="MessageMap"

    Do xData.Data.WriteLine("<MapItems>")
    
    Set key = ""
    For  {

        Set key = $Order(..tmp("MessageMap", "MessageType", key),1 , methodName)
        Quit:key=""

        Do xData.Data.WriteLine($Char(9)_$$$FormatText("<MapItem MessageType=""%1"">", key))
        Do xData.Data.WriteLine($Char(9,9)_$$$FormatText("<Method>%1</Method>", methodName))
        Do xData.Data.WriteLine($Char(9)_"</MapItem>")

    }

    Do xData.Data.WriteLine("</MapItems>")

    Do cDef.XDatas.Insert(xData)
    Return cDef.%Save()
}

ClassMethod ForceNotDefinedMAXLEN(package As %String, maxLenValue As %String = "") As %Status
{
    #dim propDef As %Dictionary.PropertyDefinition
    Set sc = $$$OK, (startKey, className) = package _"."
    
    For  {
        Set className = $Order(^oddDEF(className))
        Quit:$Extract(className, 1, $LENGTH(startKey))'=startKey

        Set classDef = ##class(%Dictionary.ClassDefinition).%OpenId(className,, .scO)
        If $$$ISERR(sc) {
            Set sc = $$$ADDSC(sc, scO)
            Continue
        }

        Set key = ""
        For  {
            Set propDef = classDef.Properties.GetNext(.key)
            Quit:key=""
            If "%String,%Library.String,%VarString"[propDef.Type, propDef.Parameters.GetAt("MAXLEN") = "" {
                $$$zlog("Force " _ className _" " _ propDef.Name _" with MAXLEN=" _ maxLenValue)
                Do propDef.Parameters.SetAt(maxLenValue, "MAXLEN")
                Set sc = $$$ADDSC(sc, propDef.%Save()) 
            }
        }
    }

    Quit sc
}

XData ProductionDefinitionTemplate
{
<Production Name="{application}" LogGeneralTraceEvents="false">
  <Description></Description>
  <ActorPoolSize>2</ActorPoolSize>
  {services}
  <Item Name="{ensOperationClassName}" Category="" ClassName="{ensOperationClassName}" PoolSize="1" Enabled="true" Foreground="false" Comment="" LogTraceEvents="false" Schedule="">
    <Setting Target="Adapter" Name="HTTPServer">{server}</Setting>
    <Setting Target="Adapter" Name="SSLConfig">{SSLConfig}</Setting>
    <Setting Target="Adapter" Name="HTTPPort">{port}</Setting>
    <Setting Target="Adapter" Name="URL">{URL}</Setting>
  </Item>
  <Item Name="{ensProcessClassName}" Category="" ClassName="{ensProcessClassName}" PoolSize="1" Enabled="true" Foreground="false" Comment="" LogTraceEvents="false" Schedule="">
  </Item>
  <Item Name="{ensProcessSyncClassName}" Category="" ClassName="{ensProcessSyncClassName}" PoolSize="1" Enabled="true" Foreground="false" Comment="" LogTraceEvents="false" Schedule="">
  </Item>
</Production>
}

}
