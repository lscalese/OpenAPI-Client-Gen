Class dc.openapi.client.Generator Extends %RegisteredObject
{

Parameter PKGMSG = "msg";

Parameter PKGBS = "bs";

Parameter PKGBO = "bo";

Parameter PKGBP = "bp";

Parameter PKGREST = "rest";

Parameter PKGMODEL = "model";

/// Grongier.OpenApi.Definition compatibility
Parameter PKGDEF = "model.Definition";

Parameter CFLAGS = "cku";

Property spec As %DynamicObject;

Property application As %String;

/// if true, only a simple http client is generated instead of an Interoperability Production.<br/>
Property simpleHttpClientOnly As %Boolean [ InitialExpression = 0 ];

Property compile As %Boolean [ InitialExpression = 1 ];

Property ensOperationClassName As %String [ Private ];

Property ensGenericResponseClassName As %String [ Private ];

Property ensProcessClassName As %String [ Private ];

Property ensProcessSyncClassName As %String [ Private ];

Property ensProxyServiceClassName As %String [ Private ];

Property restClassName As %String [ Private ];

Property packageRequest As %String [ Private ];

Property packageBusinessServices As %String [ Private ];

Property packageBusinessOperations As %String [ Private ];

Property packageBusinessProcesses As %String [ Private ];

Property packageRest As %String [ Private ];

Property packageModel As %String [ Private ];

Property packageDefinition As %String [ Private ];

Property parsedReponseClassName As %String [ Private ];

Property utilsClassname As %String [ Private ];

Property specClassName As %String [ Private ];

Property httpClientClassName As %Status [ Private ];

Property UrlMap As %Dictionary.XDataDefinition [ InitialExpression = {##class(%Dictionary.XDataDefinition).%New()}, Private ];

Property debug As %Boolean [ InitialExpression = {$Get(%zDebug,0)} ];

Property tmp As %Binary [ MultiDimensional ];

Property ensGenericResponseSuper As %String [ InitialExpression = "%Persistent,Ens.Response", Internal, Private ];

Property ensRequestSuper As %String [ InitialExpression = "%Persistent,Ens.Request", Internal, Private ];

/// To avoid erasing existing code, the generator don't overwrite existing classes.  These classes are skiped.<br/>
/// For generator testing\development purpose, It could be usefull to erase existing classes<br/>
/// Set to true if you wish this behavior or set %zOverwriteIfExist=1 in your process\terminal.
Property overwriteIfExist As %Boolean [ InitialExpression = {+$Get(%zOverwriteIfExist,0)} ];

Parameter METHODLIST = "get put post delete options head patch";

Method %OnNew(spec As %Library.DynamicObject, application As %String, compile As %Boolean = {$$$YES}, simpleHttpClientOnly As %Boolean = 0) As %Status
{
    #dim sc As %Status = $$$OK

    Set ..spec = spec
    Set ..application = application
    Set ..compile = compile
    Set ..simpleHttpClientOnly = simpleHttpClientOnly

    Set ..packageRequest = ..application _ "."_ ..#PKGMSG
    Set ..packageBusinessServices = ..application _ "."_ ..#PKGBS
    Set ..packageBusinessOperations = ..application _ "."_ ..#PKGBO
    Set ..packageBusinessProcesses = ..application _ "."_ ..#PKGBP
    Set ..packageRest = ..application _ "."_ ..#PKGREST
    Set ..packageModel = ..application _ "."_ ..#PKGMODEL
    Set ..packageDefinition = ..application _ "."_ ..#PKGDEF

    Set ..parsedReponseClassName = ..packageRequest _ ".ParsedResponse"
    Set ..ensOperationClassName = ..packageBusinessOperations _ ".Operation" 
    Set ..ensGenericResponseClassName = ..packageRequest _ ".GenericResponse" 
    Set ..ensProcessClassName = ..packageBusinessProcesses _ ".Process" 
    Set ..ensProcessSyncClassName = ..packageBusinessProcesses _ ".SyncProcess" 
    Set ..ensProxyServiceClassName = ..packageBusinessServices _ ".ProxyService"
    Set ..restClassName = ..packageRest _ ".REST"
    Set ..utilsClassname = ..application _ ".Utils"
    Set ..specClassName = ..packageModel _ ".spec"
    Set ..httpClientClassName = ..application _ ".HttpClient"

    Set ..UrlMap = ##class(%Dictionary.XDataDefinition).%New()
    Set ..UrlMap.Name = "UrlMap"
    Set ..UrlMap.XMLNamespace = "http://www.intersystems.com/urlmap"
    Do ..UrlMap.Data.WriteLine("<Routes>")

    Quit sc
}

ClassMethod name(name As %String) As %String [ CodeMode = expression ]
{
$Translate(name, "$_","")
}

Method generate() As %Status
{
    If ..simpleHttpClientOnly {
        Quit ..generateHttpClient()
    }

    Quit ..generateInteroperabilityProduction()
}

Method generateInteroperabilityProduction() As %Status
{
    #dim sc As %Status = $$$OK

    TStart 
    
    Try {
        
        
        $$$ThrowOnError(..validateSpec())
        $$$ThrowOnError(..models())                 ; Use Grongier OpenAPI-Definition to generate model
        $$$ThrowOnError(..ensGenericResponse())     ; Generate Generic Response class
        $$$ThrowOnError(..ensOperationClass())      ; Generate Business Operation (without operation method)
        $$$ThrowOnError(..restProxy())              ; Create REST Class, Utils and Projection


        #dim iter As %Iterator.AbstractIterator = ..spec.paths.%GetIterator()
        #dim serviceLocation As %String
        #dim serviceDefinition As %Library.DynamicObject
        #dim method As %String

        While iter.%GetNext(.serviceLocation , .value ) {

            Set %zCurrentData("ServiceLocation") = serviceLocation
            
            Set methodIter = value.%GetIterator()
            While methodIter.%GetNext(.method , .serviceDefinition ) {
                
                continue:..#METHODLIST'[method

                Set %zCurrentData("method") = method

                $$$ThrowOnError(..ensResponseClass(serviceDefinition))          ; Generate Ens.Response class.
                $$$ThrowOnError(..ensRequestClass(serviceDefinition, value))    ; Generate Ens.Request class.
                $$$ThrowOnError(..ensServiceClass(serviceDefinition))           ; Generate Generic Business Service class.
                $$$ThrowOnError(..ensOperationMethod(serviceDefinition))        ; Generate Operation method into Business Operation Class.
                $$$ThrowOnError(..restProxyMethod(serviceDefinition))           ; Generate Method into CSP.REST proxy api.

                Set routeUrl = $Translate(serviceLocation, "{}", ":")
                Do ..UrlMap.Data.WriteLine($$$FormatText("<Route Url=""%1"" Method=""%2"" Call=""%3""/>", routeUrl, $Zcvt(method,"U"), $Zcvt(method,"U") _ ..name(serviceDefinition.operationId) ))

            }
        
        }
        
        Do ..UrlMap.Data.WriteLine("</Routes>")
        
        $$$ThrowOnError(..ensProxyService())    ; Generate empty Business Service class for proxy usage.
        $$$ThrowOnError(..messageMap())         ; Generate XDATA Message Map bloc For Business Operation class.
        $$$ThrowOnError(..ensProcessClass())    ; Generate Generic Business Process class.
        $$$ThrowOnError(..ensProduction())      ; Generation Production configuration class.
        
        
        $$$ThrowOnError(..restProxyURLMAP())
       
        Set:..compile sc = $system.OBJ.CompilePackage(..application, ..#CFLAGS)
        
    } Catch (ex) {
        Set sc = ex.AsStatus()
    }
    
    If $$$ISOK(sc) {
        TCommit
    } Else {
        TROllback 1
    }

    Return sc
}

Method generateHttpClient() As %Status
{
    #dim sc As %Status = $$$OK

    TStart

    Try {
        
        Set (..ensGenericResponseSuper,..ensRequestSuper) = "%Persistent"   ; Change default behavior to avoid using interoperability class.
        
        $$$ThrowOnError(..validateSpec())
        $$$ThrowOnError(..models())                 ; Use Grongier OpenAPI-Definition to generate model
        $$$ThrowOnError(..ensGenericResponse())     ; Generate Generic Response class
        $$$ThrowOnError(..httpClientClass())

        #dim iter As %Iterator.AbstractIterator = ..spec.paths.%GetIterator()
        #dim serviceLocation As %String
        #dim serviceDefinition As %Library.DynamicObject
        #dim method As %String

        While iter.%GetNext(.serviceLocation , .value ) {

            Set %zCurrentData("ServiceLocation") = serviceLocation
            
            Set methodIter = value.%GetIterator()
            While methodIter.%GetNext(.method , .serviceDefinition ) {
                
                continue:..#METHODLIST'[method

                Set %zCurrentData("method") = method

                $$$ThrowOnError(..ensResponseClass(serviceDefinition))          ; Generate Ens.Response class.
                $$$ThrowOnError(..ensRequestClass(serviceDefinition, value))    ; Generate Ens.Request class.
                $$$ThrowOnError(..httpClientOperationMethod(serviceDefinition)) ; Generate Operation method into HttpClient class.

            }
        
        }
        
        Set:..compile sc = $system.OBJ.CompilePackage(..application, ..#CFLAGS)

    } Catch(ex) {
        Set sc = ex.AsStatus()
    }

    If $$$ISOK(sc) {
        TCommit
    } Else {
        TROllback
    }

    Quit sc
}

Method validateSpec() As %Status
{
    #dim sc As %Status = $$$OK

    If ..spec.swagger '= "2.0" {
        Set sc = $$$ERROR(5001,$$$FormatText("Currently this tool support only swagger 2.0 (swagger reached: %1).", ..spec.swagger))
    }

    Quit sc
}

/// Check if a package exists on server ...
ClassMethod packageExists(packageName As %String) As %Boolean
{
    Set packageList = ##class(%Dictionary.PackageDefinition).GetPackageList()
    Return ''packageList.Find($zcvt(packageName, "U"))
}

/// Generate model from Swagger "Definitions" object<br/>
/// Grongier OpenAPI-Definition is used<br/>
/// https://github.com/grongierisc/objectscript-openapi-definition
Method models() As %Status [ Private ]
{
    Set modelsGen = ##class(Grongier.OpenApi.Definition).%New( ..spec , ..packageDefinition , "%Persistent,%JSON.Adaptor,%XML.Adaptor" )
    Set modelsGen.compile = 0   ; package will be compiled with the production
    ; Set modelsGen.compileFlags = ..#CFLAGS

    Quit modelsGen.mProcess()
}

/// Generate Response classes<br/>
Method ensGenericResponse() As %Status [ Private ]
{
    #dim sc As %Status = $$$OK

    If '$$$defClassDefined(..parsedReponseClassName) {
        
        #dim parsedResponseClass As %Dictionary.ClassDefinition = ##class(%Dictionary.ClassDefinition).%New(..parsedReponseClassName)

        Set parsedResponseClass.Super = "%Persistent,%XML.Adaptor"
        Set parsedResponseClass.ProcedureBlock = $$$YES
        
        $$$QuitOnError(parsedResponseClass.%Save())
        
    }

    Set genericResponseClassName = ..ensGenericResponseClassName

    If $$$defClassDefined(..ensGenericResponseClassName) {

        If ..overwriteIfExist {

            $$$QuitOnError($$Delete^%apiOBJ(..ensGenericResponseClassName,"-d"))

        } Else {

            Write:..debug !,..ensGenericResponseClassName, " already exists, class skipped"
            Return $$$OK
        }
    }

    #dim cDef As %Dictionary.ClassDefinition = ##class(%Dictionary.ClassDefinition).%New(..ensGenericResponseClassName)
    ;Set cDef.Super = "%Persistent,Ens.Response"
    Set cDef.Super = ..ensGenericResponseSuper
    Set cDef.Inheritance = "left"
    Set cDef.ProcedureBlock = $$$YES

    #dim property As %Dictionary.PropertyDefinition
    Set property = ##class(%Dictionary.PropertyDefinition).%New()
    Set property.Name = "httpStatusCode"
    Set property.Type = "%Integer"
    Do cDef.Properties.Insert(property)

    Set property = ##class(%Dictionary.PropertyDefinition).%New()
    Set property.Name = "headers"
    Set property.Type = "%String"
    Set property.Collection = "array"
    Do property.Parameters.SetAt(128, "MAXLEN")
    Do property.Parameters.SetAt(1, "TRUNCATE")
    Do cDef.Properties.Insert(property)

    Set property = ##class(%Dictionary.PropertyDefinition).%New()
    Set property.Name = "body"
    Set property.Type = "%Stream.GlobalBinary"
    Do cDef.Properties.Insert(property)

    Set property = ##class(%Dictionary.PropertyDefinition).%New()
    Set property.Name = "operation"
    Set property.Type = "%String"
    Do property.Parameters.SetAt(128, "MAXLEN")
    Do property.Parameters.SetAt(1, "TRUNCATE")
    Do cDef.Properties.Insert(property)

    Set property = ##class(%Dictionary.PropertyDefinition).%New()
    Set property.Name = "operationStatusText"
    Set property.Type = "%String"
    Do property.Parameters.SetAt(128, "MAXLEN")
    Do property.Parameters.SetAt(1, "TRUNCATE")
    Do cDef.Properties.Insert(property)

    Set property = ##class(%Dictionary.PropertyDefinition).%New()
    Set property.Name = "parsedResponse"
    Set property.Type = ..parsedReponseClassName
    
    Do cDef.Properties.Insert(property)
    
    $$$QuitOnError(cDef.%Save())

    Return sc
}

/// Generate Business Operation class<br/>
/// Method are generate, it will generate by ensOperationMethod<br/>
/// 
Method ensOperationClass() As %Status [ Private ]
{
    #dim sc As %Status = $$$OK
    
    If $$$defClassDefined(..ensOperationClassName) {
        
        If ..overwriteIfExist {
            
            $$$QuitOnError($$Delete^%apiOBJ(..ensOperationClassName,"-d"))

        } Else {
            Write:..debug !,..ensOperationClassName, " already exists, class skipped"
            Quit $$$OK
        }
    }

    #dim cDef As %Dictionary.ClassDefinition = ##class(%Dictionary.ClassDefinition).%New(..ensOperationClassName)
    Set cDef.Super = "Ens.BusinessOperation"
    Set cDef.ProcedureBlock = $$$YES

    #dim property As %Dictionary.PropertyDefinition = ##class(%Dictionary.PropertyDefinition).%New()
    Set property.Name = "Adapter"
    Set property.Type = "EnsLib.HTTP.OutboundAdapter"
    Do cDef.Properties.Insert(property)

    Set classParameter = ..createClassParameter("ADAPTER", "EnsLib.HTTP.OutboundAdapter")
    Do cDef.Parameters.Insert(classParameter)


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

    Set sc = cDef.%Save()

	Return sc
}

/// Http client class<br/>
/// 
Method httpClientClass() As %Status [ Private ]
{
    #dim sc As %Status = $$$OK
    
    If $$$defClassDefined(..httpClientClassName) {
        
        If ..overwriteIfExist {
            
            $$$QuitOnError($$Delete^%apiOBJ(..httpClientClassName,"-d"))

        } Else {
            Write:..debug !,..httpClientClassName, " already exists, class skipped"
            Quit $$$OK
        }
    }

    #dim cDef As %Dictionary.ClassDefinition = ##class(%Dictionary.ClassDefinition).%New(..httpClientClassName)
    Set cDef.Super = "%RegisteredObject"
    Set cDef.ProcedureBlock = $$$YES

    Set mDef = ##class(%Dictionary.MethodDefinition).%New()
    Set mDef.Name = "genericProcessResponse"
    Set mDef.FormalSpec = $$$FormatText("pRequest:%1,pResponse:%2,caller:%String,status:%Status,pHttpResponse:%Net.HttpResponse,parsedResponseClassName:%String", "%RegisteredObject", ..ensGenericResponseClassName)
    Set mDef.ReturnType = "%Status"
    Set bck = ..utilsClassname
    Set ..utilsClassname = ..httpClientClassName
    Do ..genericResponseImpl( mDef) 
    Set ..utilsClassname = bck
    Do cDef.Methods.Insert(mDef)

    Set mDef = ##class(%Dictionary.MethodDefinition).%New()
    Set mDef.Name = "GetRequest"
    Set mDef.FormalSpec = $$$FormatText("pRequest:%1","%RegisteredObject")
    Set mDef.ReturnType = "%Net.HttpRequest"

    Do mDef.Implementation.WriteLine($Char(9) _"#dim pHttpRequestIn As %Net.HttpRequest = ##class(%Net.HttpRequest).%New()")
    Do mDef.Implementation.WriteLine($Char(9) _"Do:##class(%Dictionary.CompiledProperty).%ExistsId(pRequest.%ClassName(1)_""||accept"") pHttpRequestIn.SetHeader(""accept"", pRequest.accept)")
    Do mDef.Implementation.WriteLine($Char(9) _$$$FormatText("Set pHttpRequestIn.Server = ""%1""", $Piece(..spec.host, ":",1) ))
    Do mDef.Implementation.WriteLine($Char(9) _$$$FormatText("Set pHttpRequestIn.Port = ""%1""", $Piece(..spec.host, ":",2) ))
    Do:$Isobject(..spec.schemes)&&(..spec.schemes.%ToJSON()["https") mDef.Implementation.WriteLine($Char(9) _"Set pHttpRequestIn.Https = 1")
    Do mDef.Implementation.WriteLine($Char(9) _$$$FormatText("Set:pHttpRequestIn.Https pHttpRequestIn.SSLConfiguration = ""%1""", "default" ))
    
    Do mDef.Implementation.WriteLine($Char(9) _"Return pHttpRequestIn")
    Do cDef.Methods.Insert(mDef)


    Set mDef = ##class(%Dictionary.MethodDefinition).%New()
    Set mDef.Name = "processParsedResponse"
    Set mDef.FormalSpec = "pHttpResponse:%Net.HttpResponse,responseClass:%String,caller:%String,pRequest:%RegisteredObject,pResponse:"_..ensGenericResponseClassName
    Set originalMethod = ##class(%Dictionary.MethodDefinition).%OpenId("dc.openapi.client.Utils||processParsedResponse")
    Do mDef.Implementation.CopyFrom( originalMethod.Implementation )
    Set mDef.ReturnType = "%Status"
    Set mDef.ClassMethod = $$$YES
    Do cDef.Methods.Insert(mDef)
    
    Set sc = cDef.%Save()

	Return sc
}

Method genericResponseImpl(mDef As %Dictionary.MethodDefinition) As %Status
{
    Do mDef.Implementation.WriteLine($Char(9) _"Set sc = $$$OK")
    Do mDef.Implementation.WriteLine($Char(9) _"Set pResponse.operation = caller")
    Do mDef.Implementation.WriteLine($Char(9) _"Set pResponse.operationStatusText = $SYSTEM.Status.GetOneErrorText(status)")
    Do mDef.Implementation.WriteLine($Char(9) _"If $Isobject(pHttpResponse) {")
    Do mDef.Implementation.WriteLine($Char(9,9) _"Set pResponse.httpStatusCode = pHttpResponse.StatusCode")
    Do mDef.Implementation.WriteLine($Char(9,9) _"Do pResponse.body.CopyFrom(pHttpResponse.Data)")
    Do mDef.Implementation.WriteLine($Char(9,9) _"Set key = """"")
    Do mDef.Implementation.WriteLine($Char(9,9) _"For  {")
    Do mDef.Implementation.WriteLine($Char(9,9,9) _"Set key = $Order(pHttpResponse.Headers(key),1 , headerValue)")
    Do mDef.Implementation.WriteLine($Char(9,9,9) _"Quit:key=""""")
    Do mDef.Implementation.WriteLine($Char(9,9,9) _"Do pResponse.headers.SetAt(headerValue, key)")
    Do mDef.Implementation.WriteLine($Char(9,9) _"}")
    Do mDef.Implementation.WriteLine($Char(9,9) _"Set sc = ##class("_ ..utilsClassname _").processParsedResponse(pHttpResponse, parsedResponseClassName, caller, pRequest, pResponse)")
    Do mDef.Implementation.WriteLine($Char(9) _"}")
    Do mDef.Implementation.WriteLine($Char(9) _"Return sc")
    Quit $$$OK
}

/// Generate class for Proxy service<br/>
/// %CSP.REST class, Utils and a projection class used to setting up the rest application at compile time.<br/>
Method restProxy() As %Status [ Private ]
{
    #dim sc As %Status = $$$OK
    
    Quit:$$$defClassDefined(..restClassName) sc

    #dim cDef As %Dictionary.ClassDefinition = ##class(%Dictionary.ClassDefinition).%New(..restClassName)
    
    Set cDef.ProcedureBlock = $$$YES

    Set utilsClass =..application_".Utils"

    If '$$$defClassDefined(utilsClass) {    ;copy utils class to the target package
    
        Merge ^oddDEF(utilsClass) = ^oddDEF("dc.openapi.client.Utils")
        Set ^oddDEF(utilsClass, 1) = utilsClass
        ; class copy, explicit compile is needed
        $$$QuitOnError($SYSTEM.OBJ.Compile(utilsClass, "ck-d"))
    }

    Set projectionClassName = ..packageRest _ ".Projection"
    
    Set restAppName = "/"_$zcvt($tr(..application,"."),"l")_"rest"

    If '$$$defClassDefined(projectionClassName) {
    
        #dim projectionClass As %Dictionary.ClassDefinition = ##class(%Dictionary.ClassDefinition).%New(projectionClassName)
        
        Set projectionClass.ProcedureBlock = $$$YES
        Set projectionClass.Super = "%Projection.AbstractProjection"

        #dim mDef As %Dictionary.MethodDefinition = ##class(%Dictionary.MethodDefinition).%New()
        
        Set mDef.Name = "CreateProjection"
        Set mDef.FormalSpec = "cls:%String,&params"
        Set mDef.ClassMethod = $$$YES
        Set mDef.ReturnType = "%Status"
        
        Do mDef.Implementation.WriteLine($c(9)_ "Return ..%CreateWebApplication()")
        
        Do projectionClass.Methods.Insert(mDef)


        Set mDef = ##class(%Dictionary.MethodDefinition).%New()

        Set mDef.Name = "RemoveProjection"
        Set mDef.FormalSpec = "cls:%String,&params,recompile:%Boolean"
        Set mDef.ClassMethod = $$$YES
        Set mDef.ReturnType = "%Status"
        Do mDef.Implementation.WriteLine($Char(9)_"New $namespace")
        Do mDef.Implementation.WriteLine($Char(9)_"Set $namespace = ""%SYS""")
        Do mDef.Implementation.WriteLine($Char(9)_"if '##class(Security.Applications).Exists("""_restAppName_""") { Quit $$$OK }" )
        Do mDef.Implementation.WriteLine($Char(9)_"Return ##class(Security.Applications).Delete("""_restAppName_""")")
        
        Do projectionClass.Methods.Insert(mDef)

        Set mDef = ##class(%Dictionary.MethodDefinition).%New()
        Set mDef.Name = "%CreateWebApplication"
        Set mDef.ClassMethod = $$$YES

        
        Do mDef.Implementation.WriteLine($Char(9)_"New $namespace")
        Do mDef.Implementation.WriteLine($Char(9)_"Set oldNs = $namespace")
        Do mDef.Implementation.WriteLine($Char(9)_"Set $namespace = ""%SYS""")
        Do mDef.Implementation.WriteLine($Char(9)_"if ##class(Security.Applications).Exists("""_restAppName_""") { Quit $$$OK }" )
        Do mDef.Implementation.WriteLine($Char(9)_"write ""Create web application ..."",!")
        Do mDef.Implementation.WriteLine($Char(9)_"set webName = """_restAppName_"""")
        Do mDef.Implementation.WriteLine($Char(9)_"set webProperties(""NameSpace"") = oldNs")
        Do mDef.Implementation.WriteLine($Char(9)_"set webProperties(""Enabled"") = 1")
        Do mDef.Implementation.WriteLine($Char(9)_"set webProperties(""CSPZENEnabled"") = 1")
        Do mDef.Implementation.WriteLine($Char(9)_"set webProperties(""AutheEnabled"") = 64")
        Do mDef.Implementation.WriteLine($Char(9)_"set webProperties(""iKnowEnabled"") = 1")
        Do mDef.Implementation.WriteLine($Char(9)_"set webProperties(""DeepSeeEnabled"") = 1")
        Do mDef.Implementation.WriteLine($Char(9)_"Set webProperties(""DispatchClass"")="""_..restClassName_"""")
        Do mDef.Implementation.WriteLine($Char(9)_"Set webProperties(""MatchRoles"")="":%DB_"" _ oldNs")
        Do mDef.Implementation.WriteLine($Char(9)_"set sc = ##class(Security.Applications).Create(webName, .webProperties)")
        Do mDef.Implementation.WriteLine($Char(9)_"write !,""Web application creation status "", $SYSTEM.Status.GetOneErrorText(sc),! ")
        Do mDef.Implementation.WriteLine($Char(9)_"Quit $$$OK")
        
        Do projectionClass.Methods.Insert(mDef)
        
        $$$QuitOnError(projectionClass.%Save())

    }
    


    Set cDef.Super = "%CSP.REST"
    

    #dim projection As %Dictionary.ProjectionDefinition = ##class(%Dictionary.ProjectionDefinition).%New()
    Set projection.Name = "WebApp"
    Set projection.Type = projectionClassName

    Do cDef.Projections.Insert(projection)

    ; Add swagger spec

    Set mDef = ##class(%Dictionary.MethodDefinition).%New()
    Set mDef.Name = "SwaggerSpec"
    Set mDef.ClassMethod = $$$YES
    Set mDef.ReturnType = "%Status"

    Set line = $Char(9) _ "Set sc = $$$OK, swagger = ##class(%1).getSwaggerSpec(""%2"", ""OpenAPI"", ""%3"", .sc)"
    Set line = $$$FormatText(line, ..utilsClassname, ..specClassName, restAppName)
    Do mDef.Implementation.WriteLine( line )

    Do mDef.Implementation.WriteLine( $Char(9) _ "Quit:$$$ISERR(sc) sc")
    Do mDef.Implementation.WriteLine( $Char(9) _ "Set %response.ContentType = ""application/json""")
    Do mDef.Implementation.WriteLine( $Char(9) _ "Write swagger.%ToJSON()")
    Do mDef.Implementation.WriteLine( $Char(9) _ "Quit sc")

    Do cDef.Methods.Insert(mDef)
    
    Do ..UrlMap.Data.WriteLine($$$FormatText("<Route Url=""%1"" Method=""%2"" Call=""%3""/>", "/_spec", "GET", "SwaggerSpec" ))

    Return cDef.%Save()
}

Method ensResponseClass(serviceDefinition As %Library.DynamicObject) As %Status [ Private ]
{
    #dim sc As %Status = $$$OK

    Quit:'$Isobject(serviceDefinition.responses) sc

    Set iter = serviceDefinition.responses.%GetIterator()

    Set tPropInfo = "", cnt = 0

    While iter.%GetNext(.HttpStatus, .httpStatusDef) {
        
        Set array = $$$NO
        
        If httpStatusDef.schema.type="array" {

            Set ref = $Extract(httpStatusDef.schema.items."$ref", 15, *), array = $$$YES

        } Else {

            Set ref = $Extract(httpStatusDef.schema."$ref", 15, *)

        }

        If ref '= "" {
            Set $List(tPropInfo, $Increment(cnt)) = HttpStatus _ ":" _ ref _ ":" _ array _ ":"
        }
    }

    Quit:$ll(tPropInfo)=0 sc    ; no object to parse defined

    Set className = ..packageRequest _ "." _ ..name(serviceDefinition.operationId_"Response")
    
    Quit:$$$defClassDefined(className) sc
    
    
    #dim cDef As %Dictionary.ClassDefinition = ##class(%Dictionary.ClassDefinition).%New(className)
    Set cDef.Super = ..parsedReponseClassName
    Set cDef.ProcedureBlock = $$$YES

    #dim parsedResponse As %Dictionary.PropertyDefinition

    
    Set ptr = 0

    While $Listnext(tPropInfo, ptr, propItem) {
        
        Set statusCode = $Piece(propItem, ":", 1)
        Set ref = ..name($Piece(propItem, ":", 2))
        Set array = $Piece(propItem, ":", 3)
        Set type = ..packageDefinition _ "." _ ref

        Set parsedResponse = ##class(%Dictionary.PropertyDefinition).%New()

        Set pName = $Select(array:"list",1:"") _ ref
        Set parsedResponse.Name = pName
        Set parsedResponse.Type = ..packageDefinition _ "." _ ref
        
        Set:array parsedResponse.Collection = "list"
        Do cDef.Properties.Insert(parsedResponse)

        Do cDef.Parameters.Insert(..createClassParameter(statusCode _ "ISLIST", array))
        Do cDef.Parameters.Insert(..createClassParameter(statusCode _ "MODEL", parsedResponse.Name))
        Do cDef.Parameters.Insert(..createClassParameter(statusCode _ "MODELTYPE", parsedResponse.Type))

        Set ..tmp("ensResponse" _ statusCode, serviceDefinition.operationId) = parsedResponse.Type

    }
    
    Set ..tmp("ensResponse", serviceDefinition.operationId) = className
        
    $$$QuitOnError(cDef.%Save())

    Return sc
}

/// Generate response class for a HTTP Status code 200<br/>
/// 
/// Generate Ens.Request classes<br/>
Method ensRequestClass(serviceDefinition As %Library.DynamicObject, value As %Library.DynamicObject) As %Status [ Private ]
{
    #dim sc As %Status = $$$OK
    Set className = ..packageRequest _ "." _ ..name(serviceDefinition.operationId) _ "Request"
    
    If $$$defClassDefined(className) {
    
        If ..overwriteIfExist {
    
            $$$QuitOnError($$Delete^%apiOBJ(className,"-d"))
    
        } Else {
            
            Set requestParamLocation =  "accept:header:accept:%String"
            ;Set parametersObject = $Select($ISOBJECT(serviceDefinition.parameters):serviceDefinition.parameters, $ISOBJECT(value.parameters):value.parameters,1:"")
            Set parametersObject = serviceDefinition.parameters
            
            If $Isobject(parametersObject) {

                Set iterParam = parametersObject.%GetIterator()
                
                While iterParam.%GetNext(.keyParam, .parameter) {

                    Set property = ##class(%Dictionary.PropertyDefinition).%New()
                    Set pName = parameter.in _ ..name(parameter.name)
                    
                    Set pType = ..getObjectScriptType(parameter)
                    Set property.Required = $case(parameter.required,"true":$$$YES,"false":$$$NO,:+parameter.required)
                    Set collection = ""
                    
                    If parameter.type = "array" && (parameter.in = "query") && (parameter.collectionFormat = "multi") {
                        Set collection = "list"
                    } ElseIf (parameter.in = "body") && (parameter.schema.type = "array" ) {
                        Set collection = "list"
                    }

                    Set requestParamLocation = requestParamLocation _ "," _ pName _ ":" _ parameter.in _ ":" _ parameter.name _ ":" _ pType _ ":" _ collection

                }
                Set keyParam = ""
            }
            Set ..tmp("ensRequest", className, "REQUESTPARAMLOCATION") = requestParamLocation
           
            
            Return $$$OK
        }
    }

    #dim cDef As %Dictionary.ClassDefinition = ##class(%Dictionary.ClassDefinition).%New(className)
    Set cDef.ProcedureBlock = $$$YES
    Set cDef.Description = "Request Object for application : "_..application _ $$$NL_"<br/>"
                            _ "Service : "_serviceDefinition.operationId

    
    ;Set cDef.Super = "%Persistent,Ens.Request"
    Set cDef.Super = ..ensRequestSuper
    
    Set cDef.Inheritance = "left"
    
    
    /* consume property */

    Set property = ##class(%Dictionary.PropertyDefinition).%New()
    Set property.Name = "consume"
    Set property.Type = "%String"
    Set description = ""

    If $Isobject(serviceDefinition.consumes)  {
        Set consumesList = $lfs($Translate(serviceDefinition.consumes.%ToJSON(), "[]""",""),","), ptr = 0
        Set ..tmp(%zCurrentData("ServiceLocation"), %zCurrentData("method"),"consume")=consumesList
        Set description = "consume : <ul>" _ $$$NL
        While $Listnext(consumesList,ptr,mimeP) {
            Set description =  description _"<li>"_mimeP_"</li>" _ $$$NL
        }

        Set description = description _"</ul>"
    }
    Set property.Description = description
    Do cDef.Properties.Insert(property)

    

    /* accept property */

    Set producesObject = ""

    If $Isobject(serviceDefinition.produces) {
        Set producesObject = serviceDefinition.produces
    } ElseIf $Isobject(..spec.produces) {
        Set producesObject = ..spec.produces
    }

    Set property = ##class(%Dictionary.PropertyDefinition).%New()
    Set property.Name = "accept"
    Set property.Type = "%String"
    Set description=""

    If $Isobject(producesObject) {
        
        Set producesList = $lfs($Translate(producesObject.%ToJSON(), "[]""",""),","), ptr = 0
        Set ..tmp(%zCurrentData("ServiceLocation"), %zCurrentData("method"),"produce")=producesList
        Set description =  "accept : <ul>" _ $$$NL

        While $Listnext(producesList,ptr,acc) {
            Set description =  description _"<li>"_acc_"</li>" _ $$$NL
        }

        Set description =  description _"</ul>"   
    }
    Set property.Description = description
    Do cDef.Properties.Insert(property)

   
    Set requestParamLocation =  "accept:header:accept:%String"
    
    /* All parameters*/
    
    Set parametersObject = ""
    If $Isobject(serviceDefinition.parameters) {
        Set parametersObject = serviceDefinition.parameters
    } ElseIf $Isobject(value.parameters) {
        Set parametersObject = value.parameters
    }

    If $Isobject(parametersObject) {
        Set iterParam = parametersObject.%GetIterator()
        Set keyParam = ""

        While iterParam.%GetNext(.keyParam, .parameter) {
            
            If parameter."$ref" '= "" {
            
                Set ref = $Extract(parameter."$ref", 14, *)
                Set paramDef = ..spec.parameters.%Get(ref)
                
                Return:'$Isobject(paramDef) $$$ERROR($$$GeneralError, $$$FormatText("Parameter error %1", parameter."$ref"))

                Set parameter = paramDef
                     
            }

            Set property = ##class(%Dictionary.PropertyDefinition).%New()
            Set property.Name = parameter.in _ ..name(parameter.name)
            ;w !,"p|",$e(parameter.%ToJSON(),1,80)
            Set property.Type = ..getObjectScriptType(parameter)
            Set property.Required = $case(parameter.required,"true":$$$YES,"false":$$$NO,:parameter.required)
            
            If parameter.type = "array" && (parameter.in = "query") && (parameter.collectionFormat = "multi") {
                Set property.Collection = "list"
            } ElseIf (parameter.in = "body") && (parameter.schema.type = "array" ) {
                Set property.Collection = "list"
            }

            Set:parameter.description'="" property.Description =  $Replace(parameter.description, $$$NL, "<br/>" _ $$$NL )
            Do cDef.Properties.Insert(property)

            Set requestParamLocation = requestParamLocation _ "," _ property.Name _ ":" _ parameter.in _ ":" _ parameter.name _ ":" _ property.Type_":" _ property.Collection
            
        }
        Set keyParam = ""
    }
    
    Set ..tmp("ensRequest", className, "REQUESTPARAMLOCATION") = requestParamLocation

    $$$QuitOnError(cDef.%Save())
    
    Return sc
}

/// Generate Business Service class<br/>
Method ensServiceClass(serviceDefinition As %Library.DynamicObject) As %Status [ Private ]
{
    #dim sc As %Status = $$$OK

    Set serviceClassName = ..packageBusinessServices _ "." _ ..name(serviceDefinition.operationId) _ "Service"
    
    Set ..tmp("SERVICES",serviceClassName)=""

    If $$$defClassDefined(serviceClassName) {
        
        Quit:'..overwriteIfExist sc

        $$$QuitOnError($$Delete^%apiOBJ(serviceClassName,"-d"))

    }

    Set ensRequestClassName = ..packageRequest _ "." _ ..name(serviceDefinition.operationId) _ "Request"
    
    #dim cDef As %Dictionary.ClassDefinition = ##class(%Dictionary.ClassDefinition).%New(serviceClassName)

    Set cDef.Super = "Ens.BusinessService"
    Set cDef.ProcedureBlock = $$$YES

    #dim property As %Dictionary.PropertyDefinition = ##class(%Dictionary.PropertyDefinition).%New()

    Set property.Name = "Adapter"
    Set property.Type = "Ens.Adapter"
    Set property.Description = "Auto generated : Change by your Adapter type."
    Do cDef.Properties.Insert(property)

    Set classParameter = ..createClassParameter("ADAPTER", "Ens.Adapter")
    Set classParameter.Description = "Auto generated : Change by your Adapter type."
    Do cDef.Parameters.Insert(classParameter)

    #dim mDef As %Dictionary.MethodDefinition = ##class(%Dictionary.MethodDefinition).%New()

    Set mDef.Name = "OnProcessInput"
    Set mDef.Description = "Auto generated method"
    Set mDef.FormalSpec = "pInput:%RegisteredObject,pOutput:%RegisteredObject"

    Do mDef.Implementation.WriteLine($Char(9) _ "Set msg = ##class("_ensRequestClassName_").%New()")
    Do mDef.Implementation.WriteLine($Char(9) _ "; Auto generated, put your own code...")
    
    Set consumesList = $Get(..tmp(%zCurrentData("ServiceLocation"), %zCurrentData("method"),"consume")), ptr = 0
    If consumesList '= "" {
        While $Listnext(consumesList, ptr, consumeValue) {
            Do mDef.Implementation.WriteLine($Char(9) _";Set msg.consume = """ _ consumeValue _""" ; Content-Type")
        }
    }

    Set producesList = $Get(..tmp(%zCurrentData("ServiceLocation"), %zCurrentData("method"),"produce")), ptr = 0
    If producesList '="" {
        While $Listnext(producesList, ptr, produceValue) {
             Do mDef.Implementation.WriteLine($Char(9) _";Set msg.accept = """ _ produceValue _""" ; Header ACCEPT")
        }
    }

    Set pList = $lfs(..tmp("ensRequest", ensRequestClassName, "REQUESTPARAMLOCATION"),","), ptr = 0

    While $Listnext(pList, ptr, propertyName) {
        Do:($Piece(propertyName,":",1)'="accept")&&($Piece(propertyName,":",1)'="consume") mDef.Implementation.WriteLine($Char(9) _"Set msg."_$Piece(propertyName,":",1)_" = """" ; To implement")
    }

    Do mDef.Implementation.WriteLine($Char(9) _ "Return ..SendRequestAsync("""_..ensProcessClassName_""", msg)")
    
    Set mDef.ReturnType = "%Status"
    
    Do cDef.Methods.Insert(mDef)

    
    $$$QuitOnError(cDef.%Save())

    Quit sc
}

/// Generate operation method into Business Operation class<br/>
Method ensOperationMethod(serviceDefinition As %Library.DynamicObject) As %Status [ Private ]
{
    #dim cDef As %Dictionary.ClassDefinition = ##class(%Dictionary.ClassDefinition).%OpenId(..ensOperationClassName,,.sc)
    Quit:$$$ISERR(sc) sc
    Quit ..addOperationMethod( serviceDefinition , cDef )
}

Method httpClientOperationMethod(serviceDefinition As %Library.DynamicObject) As %Status [ Private ]
{
    #dim cDef As %Dictionary.ClassDefinition = ##class(%Dictionary.ClassDefinition).%OpenId(..httpClientClassName,,.sc)
    Quit:$$$ISERR(sc) sc
    Quit ..addOperationMethod( serviceDefinition , cDef )
}

Method addOperationMethod(serviceDefinition As %Library.DynamicObject, cDef As %Dictionary.ClassDefinition) As %Status [ Private ]
{
    #dim sc As %Status = $$$OK
    #dim methodName As %String = $Zcvt(%zCurrentData("method"),"U") _ ..name(serviceDefinition.operationId)
    

    #dim ensRequestClassName As %String = ..packageRequest _ "." _ ..name(serviceDefinition.operationId) _ "Request"
    Set ..tmp("MessageMap","MessageType", ensRequestClassName) = methodName
    
    If ##class(%Dictionary.MethodDefinition).%ExistsId(..ensOperationClassName _ "||" _ methodName) {
        Write:..debug !,"skipped ",methodName, " method already exists."
        Return $$$OK
    }
    
    #dim mDef As %Dictionary.MethodDefinition = ##class(%Dictionary.MethodDefinition).%New()
    Set mDef.Name = methodName
    Set mDef.Description = $Replace(serviceDefinition.description, $$$NL, "<br/>"_$$$NL)
    If cDef.Super [ "Ens.BusinessOperation" {
        Set mDef.FormalSpec = $$$FormatText("pRequest:%1,pResponse:%2", ensRequestClassName, ..ensGenericResponseClassName)
    } Else {
        Set mDef.FormalSpec = $$$FormatText("pRequest:%1,pResponse:%2,pHttpRequestIn:%Net.HttpRequest=..GetRequest(),*pHttpResponse:%Net.HttpResponse", ensRequestClassName, ..ensGenericResponseClassName)
    }
    Set mDef.ReturnType = "%Status"
    
    
    Do mDef.Implementation.WriteLine($Char(9) _"Set sc = $$$OK, pURL = """ _ ..spec.basePath _ %zCurrentData("ServiceLocation") _"""")
    Set pList = $lfs(..tmp("ensRequest", ensRequestClassName, "REQUESTPARAMLOCATION"),","), ptr = 0
    Set mParts = $$$NO
    
    Do mDef.Implementation.WriteLine($Char(9) _ "Set pHttpRequestIn = ..GetRequest(pRequest)")
    Do mDef.Implementation.WriteLine($Char(9) _ "Set pHttpRequestIn.ContentType = pRequest.consume")

    While $Listnext(pList, ptr, propertyInfo) {
        
        Set propertyName = $Piece(propertyInfo, ":", 1)
        Set in = $Piece(propertyInfo, ":", 2)
        Set parameterName = $Piece(propertyInfo, ":", 3)
        Set paramType = $Piece(propertyInfo, ":", 4)
        Set collection = $Piece(propertyInfo, ":", 5)

        Set ..tmp("RQPARAMETERS", $Zcvt(%zCurrentData("method"),"U"), serviceDefinition.operationId, in, parameterName) = propertyName

        If in = "query" {
            If collection = "list" {

                Do mDef.Implementation.WriteLine($Char(9) _ "Set key = """"")
                Do mDef.Implementation.WriteLine($Char(9) _ "For  { ")
                Do mDef.Implementation.WriteLine($Char(9,9) _ $$$FormatText("Set tmpValue = pRequest.%1.GetNext(.key)", propertyName))
                Do mDef.Implementation.WriteLine($Char(9,9) _ "Quit:key=""""")
                Do mDef.Implementation.WriteLine($Char(9,9) _ $$$FormatText("Do pHttpRequestIn.SetParam(""%1"", tmpValue, key)", parameterName))
                Do mDef.Implementation.WriteLine($Char(9) _ "}")

            } Else {
                Do mDef.Implementation.WriteLine($Char(9) _ "Do pHttpRequestIn.SetParam(""" _ parameterName _ """, pRequest." _ propertyName _")")
            }

        } ElseIf in = "path" {

            Do mDef.Implementation.WriteLine($Char(9) _ "Set pURL = $Replace(pURL, ""{"_parameterName_"}"", pRequest." _ propertyName _ ")" )

        } ElseIf (in = "header") && (parameterName'="accept") {

            Do mDef.Implementation.WriteLine($Char(9) _ "Do pHttpRequestIn.SetHeader(""" _ parameterName _ """, pRequest." _ propertyName _")")

        } ElseIf in = "formData" {

            Do mDef.Implementation.WriteLine($Char(9) _ "If pHttpRequestIn.ContentType = ""multipart/form-data"" {")
            Do mDef.Implementation.WriteLine($Char(9,9) _ "Set valueStream = ##class(%Stream.GlobalBinary).%New()")
            Do mDef.Implementation.WriteLine($Char(9,9) _ "Do:$Isobject(pRequest." _ propertyName _ ") valueStream.CopyFrom(pRequest."_propertyName_")")
            Do mDef.Implementation.WriteLine($Char(9,9) _ "Do:'$Isobject(pRequest." _ propertyName _ ") valueStream.Write($Zcvt(pRequest."_propertyName_",""I"",""UTF8""))")
            
            Do mDef.Implementation.WriteLine($Char(9,9) _ "Set:'$ISOBJECT($Get(mParts)) mParts = ##class(%Net.MIMEPart).%New()")
            Set mParts = $$$YES

            Do mDef.Implementation.WriteLine($Char(9,9) _ "Set mimePart = ##class(%Net.MIMEPart).%New(valueStream)")
            Do mDef.Implementation.WriteLine($Char(9,9) _ $$$FormatText("Do mimePart.SetHeader(""Content-Disposition"", ""form-data; name=""""%1""""; filename=""""%2"""""")", parameterName, parameterName))
            
            Do mDef.Implementation.WriteLine($Char(9,9) _ "Do mParts.Parts.Insert(mimePart)")
            Do mDef.Implementation.WriteLine($Char(9) _"} Else { ")
            Do mDef.Implementation.WriteLine($Char(9,9) _"Do pHttpRequestIn.InsertFormData("""_parameterName_""", pRequest."_propertyName_")")
            Do mDef.Implementation.WriteLine($Char(9) _"}")

        } ElseIf in = "body" {

            If paramType [ ..packageDefinition {
                If collection = "list" {
                    
                    Do mDef.Implementation.WriteLine($Char(9) _"Set bodyArray = [], key = """"")
                    Do mDef.Implementation.WriteLine($Char(9) _ "For  { ")
                    Do mDef.Implementation.WriteLine($Char(9,9) _ $$$FormatText("Set tmpValue = pRequest.%1.GetNext(.key)", propertyName))
                    Do mDef.Implementation.WriteLine($Char(9,9) _ "Quit:key=""""")
                    Do mDef.Implementation.WriteLine($Char(9,9) _ "Do tmpValue.%JSONExportToString(.tmpJSON)")
                    Do mDef.Implementation.WriteLine($Char(9,9) _ "Do bodyArray.%Push({}.%FromJSON(tmpJSON))")
                    Do mDef.Implementation.WriteLine($Char(9) _ "}")
                    Do mDef.Implementation.WriteLine($Char(9) _ "Do bodyArray.%ToJSON(pHttpRequestIn.EntityBody)")
                    
                } Else {
                    Do mDef.Implementation.WriteLine($Char(9) _"$$$QuitOnError(pRequest."_propertyName_".%JSONExportToStream(pHttpRequestIn.EntityBody))")
                }

            } Else {

                Do mDef.Implementation.WriteLine($Char(9) _"Do pHttpRequestIn.EntityBody.Write(pRequest."_propertyName_")")

            }
        }
        
    }

    If mParts {
        Do mDef.Implementation.WriteLine($Char(9) _"If $ISOBJECT($Get(mParts)) {")
        Do mDef.Implementation.WriteLine($Char(9,9) _"Set mimeWriter = ##class(%Net.MIMEWriter).%New()")
        Do mDef.Implementation.WriteLine($Char(9,9) _"Do mimeWriter.OutputToStream(.stream)")
        Do mDef.Implementation.WriteLine($Char(9,9) _"Do mimeWriter.WriteMIMEBody(mParts)")
        Do mDef.Implementation.WriteLine($Char(9,9) _"Set pHttpRequestIn.EntityBody = stream")
        Do mDef.Implementation.WriteLine($Char(9,9) _"Set pHttpRequestIn.ContentType = ""multipart/form-data; boundary="" _ mParts.Boundary")
        Do mDef.Implementation.WriteLine($Char(9) _"}")
    }

    If cDef.Super [ "Ens.BusinessOperation" {
        Do mDef.Implementation.WriteLine($Char(9) _ "$$$QuitOnError(..Adapter.SendFormDataArray(.pHttpResponse, """_ %zCurrentData("method") _""", pHttpRequestIn , , , pURL))")
    } Else {
        Do mDef.Implementation.WriteLine($Char(9) _ $$$FormatText("$$$QuitOnError(pHttpRequestIn.Send(""%1"", pURL))", $Zcvt(%zCurrentData("method"), "U") ))
        Do mDef.Implementation.WriteLine($Char(9) _ "Set pHttpResponse=pHttpRequestIn.HttpResponse")
    }
    Do mDef.Implementation.WriteLine($Char(9) _ $$$FormatText("Set pResponse = ##class(%1).%New()", ..ensGenericResponseClassName))
    
    Do mDef.Implementation.WriteLine($Char(9) _ "Set sc = ..genericProcessResponse(pRequest, pResponse, """_methodName_""", sc, $Get(pHttpResponse),"""_$Get(..tmp("ensResponse", serviceDefinition.operationId))_""")")
    Do mDef.Implementation.WriteLine($Char(9) _ "Return sc")
    Do cDef.Methods.Insert(mDef)

    Return cDef.%Save()
}

/// Generate Method into CSP.REST Proxy api <br/>
Method restProxyMethod(serviceDefinition As %Library.DynamicObject) As %Status [ Private ]
{
    #dim sc As %Status = $$$OK
    #dim ensRequestClassName As %String = ..packageRequest _ "." _ ..name(serviceDefinition.operationId) _ "Request"
    #dim utilsClass As %String =..application_".Utils"
    #dim pList As %List = $lfs(..tmp("ensRequest", ensRequestClassName, "REQUESTPARAMLOCATION"),",")
    #dim ptr As %Integer = 0
    #dim cDef As %Dictionary.ClassDefinition = ##class(%Dictionary.ClassDefinition).%OpenId(..restClassName)
    #dim mDef As %Dictionary.MethodDefinition = ##class(%Dictionary.MethodDefinition).%New()
    
    Set cDef.ProcedureBlock = $$$YES

    Set methodName = $Zcvt(%zCurrentData("method"),"U") _ ..name(serviceDefinition.operationId)

    If ##class(%Dictionary.MethodDefinition).%ExistsId(..restClassName_"||"_methodName) {
        Return sc
    }

    Set mDef.Name = methodName
    Set mDef.Description = $Replace(serviceDefinition.description, $$$NL, "<br/>"_$$$NL)
    Set mDef.FormalSpec = ""
    Set mDef.ReturnType = "%Status"
    Set mDef.ClassMethod = $$$YES

    Do mDef.Implementation.WriteLine($Char(9)_$Replace("Set ensRequest = ##class(%1).%New()", "%1", ensRequestClassName))
    Do mDef.Implementation.WriteLine($Char(9)_"Set ensRequest.consume = %request.ContentType")
    Do mDef.Implementation.WriteLine($Char(9)_"Set ensRequest.accept = $Get(%request.CgiEnvs(""HTTP_ACCEPT""),""*/*"")")
    
    #dim propertyName As %String
    #dim in As %String
    #dim parameterName As %String
    #dim paramType As %String

    #define ListQryLine "Set k=""""  For  { Set k=$Order(%request.Data(""%2"", k), 1, vData) Quit:k=""""  Do ensRequest.%1.Insert(vData) }"
    
    While $Listnext(pList, ptr, propertyInfo) {            

        Set propertyName = $Piece(propertyInfo, ":", 1)
        Set in = $Piece(propertyInfo, ":", 2)
        Set parameterName = $Piece(propertyInfo, ":", 3)
        Set paramType = $Piece(propertyInfo, ":", 4)
        Set collection = $Piece(propertyInfo, ":", 5)

        If in = "query" {
            
            If collection = "list" {
                Set line = $$$ListQryLine
            } Else {
                Set line = "Set ensRequest.%1 = $Get(%request.Data(""%2"",1))"
            }
            Do mDef.Implementation.WriteLine($Char(9)_$$$FormatText(line, propertyName, parameterName))

        } ElseIf in = "path" {

            Set line = "Set ensRequest.%1 = %2"
            Do mDef.Implementation.WriteLine($Char(9)_$$$FormatText(line, propertyName, parameterName))
            Set mDef.FormalSpec = mDef.FormalSpec_","_parameterName_":%String"

        } ElseIf (in = "header") &&(parameterName'="accept") {    

            Set line = "Set ensRequest.%1 = $Get(%request.CgiEnvs(""%2""))"
            Set convertedParameterName = "HTTP_" _ $Zconvert($Translate(parameterName, "-", "_"), "U")
            Do mDef.Implementation.WriteLine($Char(9)_$$$FormatText(line, propertyName, convertedParameterName))

        } ElseIf in = "formData" {

            If paramType = "%Stream.GlobalBinary" {

                Set line = "set mime = %request.GetMimeData(""%1"")"
                Do mDef.Implementation.WriteLine($Char(9)_$$$FormatText(line, parameterName))
                Set line = "Do:$Isobject(mime) ensRequest.%1.CopyFrom(mime)"
                Do mDef.Implementation.WriteLine($Char(9)_$$$FormatText(line, propertyName))

            } Else {
                If collection = "list" {
                    Set line = $$$ListQryLine
                } Else {
                    Set line = "Set ensRequest.%1 = $Get(%request.Data(""%2"",1))"
                }
                Do mDef.Implementation.WriteLine($Char(9)_$$$FormatText(line, propertyName, parameterName))

            }
            
        } ElseIf in = "body" {

            If paramType [ ..packageDefinition {

                If collection = "list" {
                    
                    Do mDef.Implementation.WriteLine($Char(9)_"Set bodyArray = [].%FromJSON(%request.Content), key=""""")
                    Do mDef.Implementation.WriteLine($Char(9)_"Set iter = bodyArray.%GetIterator()")
                    Do mDef.Implementation.WriteLine($Char(9)_"While iter.%GetNext(.key, .jsObj) {")
                    Set line = "Set tmpObj = ##class(%1).%New()"
                    Do mDef.Implementation.WriteLine($Char(9,9)_$$$FormatText(line, paramType))
                    Do mDef.Implementation.WriteLine($Char(9,9)_"Do tmpObj.%JSONImport(jsObj)")
                    Set line = "Do ensRequest.%1.Insert(tmpObj)"
                    Do mDef.Implementation.WriteLine($Char(9,9)_$$$FormatText(line, propertyName))
                    Do mDef.Implementation.WriteLine($Char(9)_"}")

                } Else {

                    Set line = "Set ensRequest.%1 = ##class(%2).%New()"
                    Do mDef.Implementation.WriteLine($Char(9)_$$$FormatText(line, propertyName,paramType))
                    Set line = "Do ensRequest.%1.%JSONImport(%request.Content)"
                    Do mDef.Implementation.WriteLine($Char(9)_$$$FormatText(line, propertyName))
                }

            } Else {

                Set line = "Do ensRequest.%1.CopyFrom(%request.Content)"
                Do mDef.Implementation.WriteLine($Char(9)_$$$FormatText(line, propertyName))
            }

            
        }
    }
    Set mDef.FormalSpec = $Extract(mDef.FormalSpec, 2, *)
    
    
    ;Do mDef.Implementation.WriteLine($Char(9)_$$$FormatText("Return ##class(%1).invokeHostAsync(""%2"", ensRequest, ""%3"")", utilsClass, ..ensProcessClassName, ..ensProxyServiceClassName))
    ;$$$QuitOnError(##class(petshop.Utils).invokeHostSync("petshop.bp.Process", ensRequest, "petshop.bs.ProxyService", , .pResponse))
    Do mDef.Implementation.WriteLine($Char(9)_$$$FormatText("$$$QuitOnError(##class(%1).invokeHostSync(""%2"", ensRequest, ""%3"", , .pResponse))", utilsClass, ..ensProcessSyncClassName, ..ensProxyServiceClassName))
    Do mDef.Implementation.WriteLine($Char(9)_$$$FormatText("Do ##class(%1).fillReponse(pResponse)", utilsClass))
    Do mDef.Implementation.WriteLine($Char(9)_"Do pResponse.body.OutputToDevice()")
    Do mDef.Implementation.WriteLine($Char(9)_"Return $$$OK")
    

    Do cDef.Methods.Insert(mDef)

    Return cDef.%Save()
}

/// Generate Proxy Business Service<br/>
Method ensProxyService() As %Status [ Private ]
{
    #dim sc As %Status = $$$OK
    #dim serviceClassName As %String = ..ensProxyServiceClassName

    Set ..tmp("SERVICES",..ensProxyServiceClassName)=""
    
    If $$$defClassDefined(..ensProxyServiceClassName) {

        Quit:'..overwriteIfExist sc

        $$$QuitOnError($$Delete^%apiOBJ(..ensProxyServiceClassName,"-d"))

    }
    
    #dim cDef As %Dictionary.ClassDefinition = ##class(%Dictionary.ClassDefinition).%New(..ensProxyServiceClassName)
    
    Set cDef.Super = "Ens.BusinessService"
    Set cDef.ProcedureBlock = $$$YES

    $$$QuitOnError(cDef.%Save())
    
    Return sc
}

/// Generate Message Map XDATA for Business Operation class<br/>
Method messageMap() As %Status [ Private ]
{
    #dim cDef As %Dictionary.ClassDefinition = ##class(%Dictionary.ClassDefinition).%OpenId(..ensOperationClassName,,.sc)

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

/// Generate Generic Business Process classes<br/>
Method ensProcessClass() As %Status [ Private ]
{
    #dim sc As %Status = $$$OK
    
    If $$$defClassDefined(..ensProcessClassName) {
        
        Quit:'..overwriteIfExist sc

        $$$QuitOnError($$Delete^%apiOBJ(..ensProcessClassName,"-d"))
        
    }

    Set cDef = ##class(%Dictionary.ClassDefinition).%New(..ensProcessClassName)
    Set cDef.ProcedureBlock = $$$YES
    Set cDef.Super = "Ens.BusinessProcess"

    Set mDef = ##class(%Dictionary.MethodDefinition).%New()
    Set mDef.Name = "OnRequest"
    Set mDef.FormalSpec = $$$FormatText("pRequest:%1,pResponse:%2", "Ens.Request", "Ens.Response")
    Set mDef.ReturnType = "%Status"
    Do mDef.Implementation.WriteLine($Char(9) _$$$FormatText("Return ..SendRequestAsync(""%1"", pRequest, 1, pRequest.%ClassName(1))", ..ensOperationClassName))
    Do cDef.Methods.Insert(mDef)

    Set mDef = ##class(%Dictionary.MethodDefinition).%New()
    Set mDef.Name = "OnResponse"
    Set mDef.FormalSpec = "request:%Library.Persistent,response:%Library.Persistent,callrequest:%Library.Persistent,callresponse:%Library.Persistent,pCompletionKey:%String"
    Set mDef.ReturnType = "%Status"
    Do mDef.Implementation.WriteLine($Char(9) _"Return $$$OK")
    Do cDef.Methods.Insert(mDef)

    $$$QuitOnError(cDef.%Save())
    /// Sync process ...
   
    If $$$defClassDefined(..ensProcessSyncClassName) {
        
        Quit:'..overwriteIfExist sc

        $$$QuitOnError($$Delete^%apiOBJ(..ensProcessSyncClassName,"-d"))
        
    }

    Set cDef = ##class(%Dictionary.ClassDefinition).%New(..ensProcessSyncClassName)
    Set cDef.ProcedureBlock = $$$YES
    Set cDef.Super = "Ens.BusinessProcess"

    Set mDef = ##class(%Dictionary.MethodDefinition).%New()
    Set mDef.Name = "OnRequest"
    Set mDef.FormalSpec = $$$FormatText("pRequest:%1,pResponse:%2", "Ens.Request", "Ens.Response")
    Set mDef.ReturnType = "%Status"
    Do mDef.Implementation.WriteLine($Char(9) _$$$FormatText("Return ..SendRequestSync(""%1"", pRequest, .pResponse, ,pRequest.%ClassName(1))", ..ensOperationClassName))
    Do cDef.Methods.Insert(mDef)

    Set mDef = ##class(%Dictionary.MethodDefinition).%New()
    Set mDef.Name = "OnResponse"
    Set mDef.FormalSpec = "request:%Library.Persistent,response:%Library.Persistent,callrequest:%Library.Persistent,callresponse:%Library.Persistent,pCompletionKey:%String"
    Set mDef.ReturnType = "%Status"
    Do mDef.Implementation.WriteLine($Char(9) _"Return $$$OK")
    Do cDef.Methods.Insert(mDef)

    $$$QuitOnError(cDef.%Save())

    Return sc
}

Method restProxyURLMAP(serviceDefinition As %Library.DynamicObject) As %Status
{
    #dim sc As %Status = $$$OK
    #dim restClassname As %String = ..restClassName
    #dim cDef As %Dictionary.ClassDefinition = ##class(%Dictionary.ClassDefinition).%OpenId(..restClassName)
    
    Do ##class(dc.openapi.client.Spec).%RemoveXDataBlock(cDef, "UrlMap")
    
    Set cDef.Super = "%CSP.REST"
    Do cDef.XDatas.Insert(..UrlMap)

    $$$QuitOnError(cDef.%Save())

    Return sc
}

Method ensProduction() As %Status
{
    Set sc = $$$OK
    Set productionClassName = ..application_".Production"

    If $$$defClassDefined(productionClassName) {

        Quit:'..overwriteIfExist sc
    
        $$$QuitOnError($$Delete^%apiOBJ(productionClassName,"-d"))
        
    }

    

    Set strServiceTemplate = "<Item Name=""{className}"" Category="""" ClassName=""{className}"" PoolSize=""1"" Enabled=""{enabled}"" Foreground=""false"" Comment="""" LogTraceEvents=""false"" Schedule=""""></Item>"

    Set className = ""
    For  {
        Set className = $Order(..tmp("SERVICES",className))
        Quit:className=""
        Set enabled = $Select(className = ..ensProxyServiceClassName: "true", 1: "false")
        Set service($Increment(service)) = $Replace($Replace(strServiceTemplate, "{className}", className), "{enabled}", enabled)
    }
    
    Set xData=##class(%Dictionary.XDataDefinition).%New()
    Set xData.Name = "ProductionDefinition"
    
    Set xDataTemplate = ##class(%Dictionary.XDataDefinition).%OpenId(..%ClassName(1)_"||ProductionDefinitionTemplate",,.sc)
    Return:$$$ISERR(sc) sc

    
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
            Set line = $Replace(line, "{ensOperationClassName}", ..ensOperationClassName)
            Set line = $Replace(line, "{ensProcessClassName}", ..ensProcessClassName)
            Set line = $Replace(line, "{ensProcessSyncClassName}", ..ensProcessSyncClassName)
            Set line = $Replace(line, "{server}", $Piece(..spec.host, ":", 1))
            Set line = $Replace(line, "{port}", $Piece(..spec.host, ":", 2))
            Set line = $Replace(line, "{SSLConfig}", "default")
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

ClassMethod getResponseDoc(responses As %DynamicObject) As %String
{
    Return:responses="" ""
    Set doc = ""
    Set iterParam = responses.%GetIterator()
    While iterParam.%GetNext(.key, .obj) {
        Set doc = $$$NL _ "<br/>Http status code : " _ key _ $$$NL _"<br/>" _obj.description
    }
    Return doc
}

Method getObjectScriptType(parameter As %DynamicObject) As %String
{
   
    
    #define CosType(%parameter) $case(%parameter.type, "integer":"%Integer","long":"%Integer","float":"%Numeric","double":"%Double","string":"%String","byte":"%Stream.GlobalBinary","file":"%Stream.GlobalBinary","boolean":"%Boolean","date":"%String","dateTime":"%String","password":"%String","":..name($Replace($s(%parameter.schema."$ref"'="":%parameter.schema."$ref",1:%parameter."$ref"),"#/definitions/","")),:"%String")

    Set cosType = $Select(parameter.type="array": $$$CosType(parameter.items), parameter.schema.type="array": $$$CosType(parameter.schema.items),1:$$$CosType(parameter))
    
    ;Set:cosType["#/parameters/" cosType = $Replace(cosType, "#/parameters/", "")
    If ($Extract(cosType, 1) '= "%") {
        Set cosType = ..packageDefinition _ "." _ cosType
        w:'$$$defClassDefined(cosType) !,"*|costype:",cosType, "|", $$$defClassDefined(cosType)
        Set:'$$$defClassDefined(cosType) cosType = "%Stream.GlobalBinary"
    }
    Return cosType
}

Method createClassParameter(name As %String, value As %String) As %Dictionary.ParameterDefinition
{
    Set classParameter = ##class(%Dictionary.ParameterDefinition).%New()
    Set classParameter.Name = name
    Set classParameter.Default = value
    Return classParameter
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
  </Item>
  <Item Name="{ensProcessClassName}" Category="" ClassName="{ensProcessClassName}" PoolSize="1" Enabled="true" Foreground="false" Comment="" LogTraceEvents="false" Schedule="">
  </Item>
  <Item Name="{ensProcessSyncClassName}" Category="" ClassName="{ensProcessSyncClassName}" PoolSize="1" Enabled="true" Foreground="false" Comment="" LogTraceEvents="false" Schedule="">
  </Item>
</Production>
}

}
