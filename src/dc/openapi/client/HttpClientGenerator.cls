Include dc.openapi.common.macro

/// This generator create a http client class from a specification OpenAPI 3.
Class dc.openapi.client.HttpClientGenerator Extends (%RegisteredObject, dc.openapi.common.Generator)
{

Parameter PKGRESPONSE = "responses";

Property packageResponse As %String [ Private ];

Property httpClientClassName As %String [ Private ];

Property genericResponseClassName As %String [ Private ];

Property superResponse As %String [ InitialExpression = "%RegisteredObject" ];

Property superGenericResponse As %String [ InitialExpression = "%RegisteredObject" ];

Property superModel As %String [ InitialExpression = "%JSON.Adaptor,%XML.Adaptor,%RegisteredObject" ];

Method %OnNew(specification As %DynamicObject, application As %String) As %Status
{
    Set ..spec = specification
    Set ..application = application
    Set ..packageModel = ..application _ "." _..#PKGMODEL
    Set ..packageRequest = ..application _ "." _..#PKGREQUEST
    Set ..packageResponse = ..application _ "." _..#PKGRESPONSE
    Set ..httpClientClassName = ..application _ ".HttpClient"
    Set ..genericResponseClassName = ..packageResponse _ ".GenericResponse"
    Set ..superResponse = ..genericResponseClassName
    Quit $$$OK
}

Method GenerateClient() As %Status
{
    Set sc = ..GenerateModels()
    
    ; Generate class model for make request.
    Set sc = $$$ADDSC(sc, ..IterateOnOperation("GenerateRequestClass"))

    
    ; Add LoadHttpRequestObject method to request classes
    Set sc = $$$ADDSC(sc, ..IterateOnOperation("GenerateLoadHttpRequestObject"))

    ; Generate Response Classes
    Set sc = $$$ADDSC(sc, ..IterateOnOperation("GenerateResponseClass"))

    ; Generate Generic Response class (super class of all reponses classes)
    Set sc = $$$ADDSC(sc, ..GenerateGenericResponse())

    ; Generate LoadFromResponse method.
    Set sc = $$$ADDSC(sc, ..IterateOnOperation("GenerateLoadFromResponse"))

    ; Generate HttpClient class
    Set sc = $$$ADDSC(sc, ..httpClientClass())

    Set sc = $$$ADDSC(sc, ##class(dc.openapi.common.Utils).ForceNotDefinedMAXLEN( ..application _ ".model"))
    
    Quit sc
}

Method GenerateModels() As %Status
{
    $$$zlog("* Start model generation in package " _ ..packageModel)

    #dim modelGenerator As Grongier.OpenApi.DefinitionV3 = ##class(Grongier.OpenApi.DefinitionV3).%New(..spec, ..packageModel, , $$$NO)
    Set modelGenerator.super = ..superModel

    Set sc = modelGenerator.GenerateClasses()

    $$$zlog("= Models generation status : " _ $SYSTEM.Status.GetOneErrorText(sc))

    Quit sc
}

Method GenerateLoadHttpRequestObject(path As %String, pathItem As %DynamicObject, method As %String, operation As %DynamicObject) As %Status
{
    #dim propDef As %Dictionary.PropertyDefinition
    Set sc = $$$OK

    Do ..CheckAndGenerateOperationId(method, .operation, path)

    Set className = ..packageRequest _ "." _ operation.operationId

    Set classDef = ##class(%Dictionary.ClassDefinition).%OpenId(className,,.sc)

    If $$$ISERR(sc) {
        $$$zlog($Char(9) _"+ Can't add LoadHttpRequestObject method to  " _ className _ "(class definition does not exist)")
        Quit sc
    }

    $$$zlog($Char(9) _"+ Add LoadHttpRequestObject method to  " _ className)

    Set methodDef = ##class(%Dictionary.MethodDefinition).%New()
    Set methodDef.Name = "LoadHttpRequestObject"
    Set methodDef.Description = "Load %Net.HttpRequest with this property object."
    Set methodDef.FormalSpec = "&httpRequest:%Net.HttpRequest"
    Set methodDef.ClassMethod = $$$NO
    Set methodDef.ReturnType = "%Status"
    
    Do methodDef.Implementation.WriteLine( $Char(9) _ "Set sc = $$$OK")
    Do methodDef.Implementation.WriteLine( $Char(9) _ "Set httpRequest.ContentType = ..%ContentType")
    Do methodDef.Implementation.WriteLine( $Char(9) _ "Do httpRequest.SetHeader(""accept"", ..%Consume)")
    
    Do classDef.Methods.Insert(methodDef)

    Set parameters = ..GetOperationParameters(pathItem, operation)

    Set parameterIterator = parameters.%GetIterator()
    While parameterIterator.%GetNext(.key, .parameter) {

        ; parameter is a parameter object https://swagger.io/specification/#parameter-object
        
        Set:parameter."$ref"'="" parameter = ##class(dc.openapi.common.Utils).GetObjectByRef(..spec, parameter."$ref", .name)
        
        Continue:'$IsObject(parameter)
        Continue:parameter.name=""
        Continue:parameter.in=""

        #dim httpRequest As %Net.HttpRequest = ##class(%Net.HttpRequest).%New()

        Set propDef = $$$FindPropertyName(classDef, $$$NormalizePropertyParamName(parameter.in_parameter.name))
        If '$IsObject(propDef) {
            Set errMsg = $$$FormatText("Property definition %1 not found in class %2", parameter.in_parameter.name, classDef.Name)
            $$$zlog($Char(9) _ "! " _ errMsg)
            Set sc = $$$ADDSC(sc, $$$ERROR(5001, errMsg))
            Continue
        }

        Set parameterPropertyName = $$$CodeNormalizeProperty($$$NormalizePropertyParamName(parameter.in_parameter.name))

        If parameter.in = "header" {
            Do httpRequest.SetHeader(parameter.name, parameter.name)
            Set line = "Do httpRequest.SetHeader(""%1"", ..%2)"
            Do methodDef.Implementation.WriteLine( $Char(9) _ $$$FormatText(line, parameter.name, parameterPropertyName ))
        } ElseIf parameter.in = "path" {
            Set line = "Set ..%URL = $Replace(..%URL,""{%1}"", ..%2)"
            Do methodDef.Implementation.WriteLine( $Char(9) _ $$$FormatText(line, parameter.name, parameterPropertyName))
        } ElseIf parameter.in = "query" {
            If propDef.Collection '= "" {
                Do methodDef.Implementation.WriteLine( $Char(9) _ "Set key = """"")
                Do methodDef.Implementation.WriteLine( $Char(9) _ "For  {")
                Do methodDef.Implementation.WriteLine( $Char(9,9) _ "Set tmpValue = .."_parameterPropertyName_".GetNext(.key)")
                Do methodDef.Implementation.WriteLine( $Char(9,9) _ "Quit:key=""""")
                Do methodDef.Implementation.WriteLine( $Char(9,9) _ "Do httpRequest.SetParam(""" _ parameter.name _ """, tmpValue, key)")
                Do methodDef.Implementation.WriteLine( $Char(9) _ "}")
            } Else {
                Set line = "Do httpRequest.SetParam(""%1"",..%2)"
                Do methodDef.Implementation.WriteLine( $Char(9) _ $$$FormatText(line, parameter.name, parameterPropertyName))
            }
        }

    }
    

    If '$ISOBJECT(operation.requestBody)||'$ISOBJECT(operation.requestBody.content) {
        Do methodDef.Implementation.WriteLine( $Char(9) _ "Quit sc")
        Quit $$$ADDSC(sc, classDef.%Save())
    }

    Set bodyHelper = ..RequestBodyHelper(operation.requestBody.content), bodyHelperIterator = bodyHelper.%GetIterator()

    While bodyHelperIterator.%GetNext(.propertyName, .propertyDetail) {
        
        Set propDef = $$$FindPropertyName(classDef, $$$NormalizePropertyParamName(propertyName))
        If '$IsObject(propDef) {
            Set errMsg = $$$FormatText("Property definition %1 not found in class %2", propertyName, classDef.Name)
            $$$zlog($Char(9) _ "! " _ errMsg)
            Set sc = $$$ADDSC(sc, $$$ERROR(5001, errMsg))
            Continue
        }

        Set ctIterator = propertyDetail.contentType.%GetIterator()
        While ctIterator.%GetNext(.key, .contentType) {
            
            Set condition = $$$FormatText("If $Piece($$$LOWER(..%ContentType),"";"",1) = ""%1""", $$$LOWER(contentType))
            
            If propDef.Type [ "%Stream" {
                Set line = condition _" Do httpRequest.EntityBody.CopyFrom(..%1)"
                Do methodDef.Implementation.WriteLine( $Char(9) _ $$$FormatText(line, propertyName))
                Continue
            }

            If propDef.Type [ "%Dynamic" {
                Set line = condition _ " Do ..%1.%JSONExportToStream(httpRequest.EntityBody)"
                Do methodDef.Implementation.WriteLine( $Char(9) _ $$$FormatText(line, propertyName))
                Continue
            }

            If $$$LOWER(contentType) [ "application/json" {
                If propDef.Collection '= "" {
                    Do methodDef.Implementation.WriteLine( $Char(9) _ condition _ "{")
                    Do methodDef.Implementation.WriteLine( "" )
                    Do methodDef.Implementation.WriteLine( $Char(9,9) _ "Set key = """", array = []")
                    Do methodDef.Implementation.WriteLine( $Char(9,9) _ "For  {")
                    Do methodDef.Implementation.WriteLine( $Char(9,9,9) _ "Set tmpObject = .."_ propertyName _ ".GetNext(.key)")
                    Do methodDef.Implementation.WriteLine( $Char(9,9,9) _ "Quit:key=""""")
                    Do methodDef.Implementation.WriteLine( $Char(9,9,9) _ "Do tmpObject.%JSONExportToStream(.tmpStream), array.%Push({}.%FromJSON(tmpStream))")
                    Do methodDef.Implementation.WriteLine( $Char(9,9,9) _ "Kill tmpStream")
                    Do methodDef.Implementation.WriteLine( $Char(9,9) _ "}")
                    Do methodDef.Implementation.WriteLine( "" )
                    Do methodDef.Implementation.WriteLine( $Char(9,9) _ "Do array.%ToJSON(httpRequest.EntityBody)")
                    Do methodDef.Implementation.WriteLine( $Char(9) _ "}")
                } Else {
                    Set line = condition _ " Do ..%1.%JSONExportToStream(httpRequest.EntityBody)"
                    Do methodDef.Implementation.WriteLine( $Char(9) _ $$$FormatText(line, propertyName))
                }

            } ElseIf $$$LOWER(contentType) [ "application/xml" {

                Set line = condition _ " Do ..%1.XMLExportToStream(httpRequest.EntityBody)"
                Do methodDef.Implementation.WriteLine( $Char(9) _ $$$FormatText(line, propertyName))

            } ElseIf ($$$LOWER(contentType) [ "multipart/form-data") {
                
                Do methodDef.Implementation.WriteLine( $Char(9) _ condition _ "{")

                If propDef.Type = "%Stream.GlobalBinary" {
                    Set mWriter = $$$YES
                    ;Do methodDef.Implementation.WriteLine( $Char(9,9) _ "")
                    Do methodDef.Implementation.WriteLine( $Char(9,9) _ "Set valueStream = ##class(%Stream.GlobalBinary).%New()")
                    Do methodDef.Implementation.WriteLine( $Char(9,9) _ "Do valueStream.CopyFrom(.." _ propertyName _ ")")
                    ; Do methodDef.Implementation.WriteLine( $Char(9,9) _ "Set:'$IsObject($Get(mParts)) mParts = ##class(%Net.MIMEPart).%New()")
                    Do methodDef.Implementation.WriteLine( $Char(9,9) _ "Set mParts = ##class(%Net.MIMEPart).%New()")
                    Do methodDef.Implementation.WriteLine( $Char(9,9) _ "Set mimePart = ##class(%Net.MIMEPart).%New(valueStream)")
                    Do methodDef.Implementation.WriteLine( $Char(9,9) _ $$$FormatText("Do mimePart.SetHeader(""Content-Disposition"", ""form-data; name=""""%1""""; filename=""""%1"""""")", propertyName))
                    Do methodDef.Implementation.WriteLine( $Char(9,9) _ "Do mParts.Parts.Insert(mimePart)")
                } Else {
                    ; todo ...
                    Do methodDef.Implementation.WriteLine( $Char(9,9) _ "; To implement.  There is no code generation yet for this case.")
                    Do methodDef.Implementation.WriteLine( $Char(9,9) _ "$$$ThrowStatus($$$ERROR($$$NotImplemented))")
                    
                }

                Do methodDef.Implementation.WriteLine( $Char(9) _ "}")
            
            } ElseIf $$$LOWER(contentType) [ "application/octet-stream" {
                Do methodDef.Implementation.WriteLine( $Char(9) _ condition _ " {")

                If propDef.Type = "%Stream.GlobalBinary" {
                    Do methodDef.Implementation.WriteLine( $Char(9,9) _"Do httpRequest.EntityBody.CopyFrom(.."_ $$$CodeNormalizeProperty(propDef.Name) _")")
                }Else {
                    Do methodDef.Implementation.WriteLine( $Char(9,9) _ "; To implement.  There is no code generation for this case.")
                    Do methodDef.Implementation.WriteLine( $Char(9,9) _ "$$$ThrowStatus($$$ERROR($$$NotImplemented))")
                }

                Do methodDef.Implementation.WriteLine( $Char(9) _ "}")
            }Else {
                Do methodDef.Implementation.WriteLine( $Char(9) _ condition _" {")
                Do methodDef.Implementation.WriteLine( $Char(9,9) _ "; To implement.  There is no code generation yet for this case.")
                Do methodDef.Implementation.WriteLine( $Char(9,9) _ "$$$ThrowStatus($$$ERROR($$$NotImplemented))")
                Do methodDef.Implementation.WriteLine( $Char(9) _ "}")
            }

        }

    }

    If $Get(mWriter, 0) {
        Do methodDef.Implementation.WriteLine( $Char(9) _ "If $IsObject($Get(mParts)) { ; Perform only if a file is attached.")
        Do methodDef.Implementation.WriteLine( $Char(9,9) _ "Set mimeWriter = ##class(%Net.MIMEWriter).%New()")
        Do methodDef.Implementation.WriteLine( $Char(9,9) _ "Do mimeWriter.OutputToStream(.stream)")
        Do methodDef.Implementation.WriteLine( $Char(9,9) _ "Do mimeWriter.WriteMIMEBody(mParts)")
        Do methodDef.Implementation.WriteLine( $Char(9,9) _ "Set httpRequest.EntityBody = stream")
        Do methodDef.Implementation.WriteLine( $Char(9,9) _ "Set httpRequest.ContentType = ""multipart/form-data; boundary="" _ mParts.Boundary")
        Do methodDef.Implementation.WriteLine( $Char(9) _ "}")
    }

    Do methodDef.Implementation.WriteLine( $Char(9) _ "Quit sc")
    Set sc = classDef.%Save()

    Quit sc
}

Method httpClientClass() As %Status [ Private ]
{
    #dim sc As %Status = $$$OK
    
    If $$$defClassDefined(..httpClientClassName) {
        $$$QuitOnError($$Delete^%apiOBJ(..httpClientClassName,"-d"))
    }

    #dim classDef As %Dictionary.ClassDefinition = ##class(%Dictionary.ClassDefinition).%New(..httpClientClassName)
    Set classDef.Super = "%RegisteredObject"
    Set classDef.ProcedureBlock = $$$YES

    #dim classParameter As %Dictionary.ParameterDefinition = ##class(%Dictionary.ParameterDefinition).%New()
    Set classParameter.Name = "SERVER"
    Set classParameter.Default = $Select(..spec.%IsDefined("servers")&&$IsObject(..spec.servers.%Get(0)): ..spec.servers.%Get(0).url, 1:"")
    Do classDef.Parameters.Insert(classParameter)

    Set classParameter  = ##class(%Dictionary.ParameterDefinition).%New()
    Set classParameter.Name = "SSLCONFIGURATION"
    Set classParameter.Default = "DefaultSSL"
    Do classDef.Parameters.Insert(classParameter)

    Set propertyName = "Server", propDef = $$$FindPropertyName(classDef, propertyName)
    Set:'$IsObject(propDef) propDef = ##class(%Dictionary.PropertyDefinition).%New(classDef.Name _ ":" _ propertyName )
    Set propDef.InitialExpression = "..#SERVER", propDef.Type = "%String"
    Do classDef.Properties.Insert(propDef)

    Set propertyName = "SSLConfiguration", propDef = $$$FindPropertyName(classDef, propertyName)
    Set:'$IsObject(propDef) propDef = ##class(%Dictionary.PropertyDefinition).%New(classDef.Name _ ":" _ propertyName )
    Set propDef.InitialExpression = "..#SSLCONFIGURATION", propDef.Type = "%String"
    Do classDef.Properties.Insert(propDef)

    Set propertyName = "HttpRequest", propDef = $$$FindPropertyName(classDef, propertyName)
    Set:'$IsObject(propDef) propDef = ##class(%Dictionary.PropertyDefinition).%New(classDef.Name _ ":" _ propertyName )
    Set propDef.InitialExpression = "##class(%Net.HttpRequest).%New()"
    Do classDef.Properties.Insert(propDef)

    Set propertyName = "URLComponents", propDef = $$$FindPropertyName(classDef, propertyName)
    Set:'$IsObject(propDef) propDef = ##class(%Dictionary.PropertyDefinition).%New(classDef.Name _ ":" _ propertyName )
    Set propDef.MultiDimensional = $$$YES
    Do classDef.Properties.Insert(propDef)

    Set methodDef = ##class(%Dictionary.MethodDefinition).%New()
    Set methodDef.Name = "InitializeHttpRequestObject"
    Set methodDef.ReturnType = "%Status"
    Do methodDef.Implementation.WriteLine( $Char(9) _ "Set ..HttpRequest = ##class(%Net.HttpRequest).%New()" )
    Do methodDef.Implementation.WriteLine( $Char(9) _ "Do ##class(%Net.URLParser).Decompose(..Server, .components)" )
    Do methodDef.Implementation.WriteLine( $Char(9) _ "Set:$Data(components(""host""), host) ..HttpRequest.Server = host" )
    Do methodDef.Implementation.WriteLine( $Char(9) _ "Set:$Data(components(""port""), port) ..HttpRequest.Port = port" )
    Do methodDef.Implementation.WriteLine( $Char(9) _ "Set:$$$LOWER($Get(components(""scheme"")))=""https"" ..HttpRequest.Https = $$$YES, ..HttpRequest.SSLConfiguration = ..SSLConfiguration" )
    Do methodDef.Implementation.WriteLine( $Char(9) _ "Merge:$Data(components) ..URLComponents = components")
    Do methodDef.Implementation.WriteLine( $Char(9) _ "Quit $$$OK")
    Do classDef.Methods.Insert(methodDef)
    
    Set methodDef = ##class(%Dictionary.MethodDefinition).%New()
    Set methodDef.Name = "%OnNew"
    Set methodDef.FormalSpec = "Server:%String,SSLConfiguration:%String"
    Set methodDef.ReturnType = "%Status"
    Do methodDef.Implementation.WriteLine( $Char(9) _ "Set:$Data(Server) ..Server = Server")
    Do methodDef.Implementation.WriteLine( $Char(9) _ "Set:$Data(SSLConfiguration) ..SSLConfiguration = SSLConfiguration")
    Do methodDef.Implementation.WriteLine( $Char(9) _ "Quit ..InitializeHttpRequestObject()")
    Do classDef.Methods.Insert(methodDef)
    Set sc = classDef.%Save()

    Set sc = $$$ADDSC(sc, ..IterateOnOperation("GenerateMethodExecutor"))

    Set sc = classDef.%Save()

	Quit sc
}

/// Generate method that execute the http request for a service into the HttpClient class
Method GenerateMethodExecutor(path As %String, pathItem As %DynamicObject, method As %String, operation As %DynamicObject) As %Status
{
    Set sc = $$$OK
    Set classDef = ##class(%Dictionary.ClassDefinition).%OpenId(..httpClientClassName,, .sc)

    If $$$ISERR(sc) {
        $$$zlog("!cannot add executor method " _ ..httpClientClassName _ " does not exist.")
        Quit sc
    }

    $$$zlog("+ Add method " _ operation.operationId _ " to " _ ..application_"." _ ..httpClientClassName)

    Set methodDef = ##class(%Dictionary.MethodDefinition).%New()
    Set methodDef.Description = "Implement operationId : " _ operation.operationId
        _ $Char(13,10) _ method _ " " _path
    Set methodDef.Name = operation.operationId
    Set methodDef.FormalSpec = "requestMessage:" _ ..packageRequest _ "." _ operation.operationId _ ",*responseMessage:" 
        _ ..packageResponse _ "." _ operation.operationId _"=##class("_..packageResponse _ "." _ operation.operationId_").%New()"

    Set methodDef.ReturnType = "%Status"
    Do methodDef.Implementation.WriteLine( $Char(9) _ "Set sc = $$$OK")
    Do methodDef.Implementation.WriteLine( $Char(9) _ "$$$QuitOnError(requestMessage.LoadHttpRequestObject(..HttpRequest))" )
    Do methodDef.Implementation.WriteLine( $Char(9) _ $$$FormatText("$$$QuitOnError(..HttpRequest.Send(""%1"", $Get(..URLComponents(""path"")) _ requestMessage.%URL))", $ZConvert(method, "U")))
    Do methodDef.Implementation.WriteLine( $Char(9) _ "$$$QuitOnError(responseMessage.LoadFromResponse(..HttpRequest.HttpResponse, """ _ operation.operationId _ """))")
    Do methodDef.Implementation.WriteLine( $Char(9) _ "Quit sc")
    Do classDef.Methods.Insert(methodDef)

    Quit classDef.%Save()
}

Method GenerateResponseClass(path As %String, pathItem As %DynamicObject, method As %String, operation As %DynamicObject) As %Status
{
    Set sc = $$$OK

    Set className = ..packageResponse _ "." _ $$$zNormalizeClassName(operation.operationId)
    #dim classDef As %Dictionary.ClassDefinition
    $$$QuitOnError(##class(dc.openapi.common.Utils).CreateClassDefInstance(className, .classDef))
    Set classDef.Super = ..superResponse
    
    $$$zlog("* Generate response class " _className _" for " _ path _ " " _ method)

    If '$IsObject(operation.responses) Quit classDef.%Save()

    Set codeIterator = operation.responses.%GetIterator()
    While codeIterator.%GetNext(.code, .codeItem) {
        
        Continue:'$IsObject(codeItem.content)
        
        Set contentTypeIterator = codeItem.content.%GetIterator()
        While contentTypeIterator.%GetNext(.contentType, .contentTypeItem) {
            
            Continue:'contentTypeItem.%IsDefined("schema")

            If contentTypeItem.schema.%IsDefined("$ref") {
                Set ref = ##class(dc.openapi.common.Utils).GetObjectByRef(..spec, contentTypeItem.schema."$ref", .refName)
                Set k1 = ..packageModel_"."_ $$$zNormalizeClassName(refName)
                If ref.type = "array" {
                    Set ref = ##class(dc.openapi.common.Utils).GetObjectByRef(..spec, ref.items."$ref", .refName)
                    Set propertyToGen(k1, 1) = "ListOf" _ $$$zNormalizeClassName(refName)
                    Set propertyToGen(k1, 1, "description") = $Get(propertyToGen(k1, 1, "description"))
                        _ "http status code = "_code _" content-type = " _contentType_$c(13,10)
                } Else {
                    Set propertyToGen(k1, 0) = $$$zNormalizeClassName(refName)
                    Set propertyToGen(k1, 0, "description") = $Get(propertyToGen(k1, 0, "description"))
                        _ "http status code = "_code _" content-type = " _contentType_$c(13,10)
                    Set:$IsObject(ref.xml)&&(ref.xml.name'="") propertyToGen(k1, 0, "XMLNAME") = $Translate(ref.xml.name,"#%/\","")
                }

                

            } ElseIf contentTypeItem.schema.type = "array" {
                Set ref = ##class(dc.openapi.common.Utils).GetObjectByRef(..spec, contentTypeItem.schema.items."$ref", .refName)
                Set k1 = ..packageModel_"."_ $$$zNormalizeClassName(refName)
                Set propertyToGen(k1, 1) = "ListOf" _$$$zNormalizeClassName(refName)
                Set propertyToGen(k1, 1, "description") = $Get(propertyToGen(k1, 1, "description"))
                    _ "http status code = "_code _" content-type = " _contentType_$c(13,10)
            }

        }
    }

    Set key = ""
    For  {
        Set key = $Order(propertyToGen(key))
        Quit:key=""

        For i = 0, 1 {
            Continue:'$Data(propertyToGen(key, i), propertyName)

            Set propDef = $$$FindPropertyName(classDef, propertyName)
            Set:'$IsObject(propDef) propDef = ##class(%Dictionary.PropertyDefinition).%New(classDef.Name _ ":" _ propertyName )
            Set propDef.Type = key
            Set propDef.Description = $Get(propertyToGen(key, i, "description"))
            Set:i=1 propDef.Collection = "list"
            Do:$Data(propertyToGen(key, i, "XMLNAME"),xmlName) propDef.Parameters.SetAt(xmlName, "XMLNAME")
            $$$zlog($Char(9) _ "+ Add property " _ propertyName)
            Do classDef.Properties.Insert(propDef)

        }
    }

    Set sc = classDef.%Save()

    Quit sc
}

Method GenerateLoadFromResponse(path As %String, pathItem As %DynamicObject, method As %String, operation As %DynamicObject) As %Status
{
    Set sc = $$$OK
    
    Set className = ..packageResponse _ "." _ $$$zNormalizeClassName(operation.operationId)
    #dim classDef As %Dictionary.ClassDefinition = ##class(%Dictionary.ClassDefinition).%OpenId(className,,.sc)
    If $$$ISERR(sc) {
        $$$zlog($Char(9) _ "! cannot add LoadFromResponse method, class does not exist "_className)
        Quit sc
    }

    Set methodDef = ##class(%Dictionary.MethodDefinition).%New()
    Set methodDef.Description = "Implement operationId : " _ operation.operationId
        _ $Char(13,10) _ method _ " " _ path
    Set methodDef.Name = "LoadFromResponse"
    Set methodDef.FormalSpec = "httpResponse:%Net.HttpResponse,caller:%String="""""
    Set methodDef.ReturnType = "%Status"
    Do classDef.Methods.Insert(methodDef)
    Do methodDef.Implementation.WriteLine( $Char(9) _ "Set sc = $$$OK")
    Do methodDef.Implementation.WriteLine( $Char(9) _ "Do ##super(httpResponse, caller)")

    If '$IsObject(operation.responses) {
        Do methodDef.Implementation.WriteLine( $Char(9) _ "Quit sc")
        Quit classDef.%Save()
    }

    Set codeIterator = operation.responses.%GetIterator()
    While codeIterator.%GetNext(.code, .codeItem) {
        
        Continue:'$IsObject(codeItem.content)
        
        Set contentTypeIterator = codeItem.content.%GetIterator()
        While contentTypeIterator.%GetNext(.contentType, .contentTypeItem) {
            
            continue:'contentTypeItem.%IsDefined("schema")

            If contentTypeItem.schema.%IsDefined("$ref") {
                Set ref = ##class(dc.openapi.common.Utils).GetObjectByRef(..spec, contentTypeItem.schema."$ref", .refName)
                Set k1 = ..packageModel_"."_ $$$zNormalizeClassName(refName)
                If ref.type = "array" {
                    Do methodDef.Implementation.WriteLine( $Char(9) _ "If $$$LOWER($Piece(httpResponse.ContentType,"";"",1))=""" _ contentType _ """,httpResponse.StatusCode = """ _ code _ """ {")
                    Do methodDef.Implementation.WriteLine( $Char(9,9) _ "$$$ThrowStatus($$$ERROR($$$NotImplemented))")
                    Do methodDef.Implementation.WriteLine( $Char(9) _ "}")
                } Else {
                   
                    Do methodDef.Implementation.WriteLine( $Char(9) _ "If $$$LOWER($Piece(httpResponse.ContentType,"";"",1))=""" _ contentType _ """,httpResponse.StatusCode = """ _ code _ """ {")
                    If contentType = "application/json" {
                        Do methodDef.Implementation.WriteLine( $Char(9,9) _ "Set .." _ $$$zNormalizeClassName(refName) _ " = ##class("_k1 _").%New()")
                        Do methodDef.Implementation.WriteLine( $Char(9,9) _ "Do .." _ $$$zNormalizeClassName(refName) _ ".%JSONImport(httpResponse.Data)")
                        Do methodDef.Implementation.WriteLine( $Char(9,9) _ "Return sc")
                    } ElseIf contentType = "application/xml" {
                        Set xmlTagName = refName
                        
                        If $IsObject(ref.xml), ref.xml.name '= "" {
                            Set xmlTagName = $Translate(ref.xml.name,"#%/\","")
                        }

                        Do methodDef.Implementation.WriteLine( $Char(9,9) _ "Set reader = ##class(%XML.Reader).%New()" )
                        Do methodDef.Implementation.WriteLine( $Char(9,9) _ "$$$QuitOnError(reader.OpenStream(httpResponse.Data))")
                        Do methodDef.Implementation.WriteLine( $Char(9,9) _ "Do reader.Correlate(""" _ xmlTagName _ """,""" _ k1 _""")" )
                        Do methodDef.Implementation.WriteLine( $Char(9,9) _ "Do reader.Next(." _ $$$zNormalizeClassName(refName) _ ", .sc)" )
                        Do methodDef.Implementation.WriteLine( $Char(9,9) _ "If $$$ISERR(sc) Quit sc" )
                        Do methodDef.Implementation.WriteLine( $Char(9,9) _ "Set .." _ $$$zNormalizeClassName(refName) _ " = " _ $$$zNormalizeClassName(refName) )
                        Do methodDef.Implementation.WriteLine( $Char(9,9) _ "Return sc")
                    } Else {
                        Do methodDef.Implementation.WriteLine( $Char(9,9) _ "$$$ThrowStatus($$$ERROR($$$NotImplemented))")
                    }
                    Do methodDef.Implementation.WriteLine( $Char(9) _ "}")
                }
            } ElseIf contentTypeItem.schema.type = "array" {
                Set ref = ##class(dc.openapi.common.Utils).GetObjectByRef(..spec, contentTypeItem.schema.items."$ref", .refName)
                Set k1 = ..packageModel_"."_ $$$zNormalizeClassName(refName)
                
                Do methodDef.Implementation.WriteLine( $Char(9) _ "If $$$LOWER($Piece(httpResponse.ContentType,"";"",1))=""" _ contentType _ """,httpResponse.StatusCode = """ _ code _ """ {")
                If contentType = "application/json" {
                    Do methodDef.Implementation.WriteLine( $Char(9,9) _ "Set array = [].%FromJSON(httpResponse.Data), iterator = array.%GetIterator()")
                    Do methodDef.Implementation.WriteLine( $Char(9,9) _ "While iterator.%GetNext(.index, .item) {")
                    Do methodDef.Implementation.WriteLine( $Char(9,9,9) _ "Set obj = ##class("_k1 _").%New()")
                    Do methodDef.Implementation.WriteLine( $Char(9,9,9) _ "Do obj.%JSONImport(item), ..ListOf" _ $$$zNormalizeClassName(refName) _ ".Insert(obj)")
                    Do methodDef.Implementation.WriteLine( $Char(9,9) _ "}")
                    Do methodDef.Implementation.WriteLine( $Char(9,9) _ "Return sc")
                } ElseIf contentType = "application/xml" {
                        
                        Set xmlTagName = refName
                        
                        If $IsObject(ref.xml), ref.xml.name '= "" Set xmlTagName = $Translate(ref.xml.name,"#%/\","")

                        Do methodDef.Implementation.WriteLine( $Char(9,9) _ "Set reader = ##class(%XML.Reader).%New()" )
                        Do methodDef.Implementation.WriteLine( $Char(9,9) _ "$$$QuitOnError(reader.OpenStream(httpResponse.Data))")
                        Do methodDef.Implementation.WriteLine( $Char(9,9) _ "Do reader.Correlate(""" _ xmlTagName _ """,""" _ k1 _""")" )
                        Do methodDef.Implementation.WriteLine( $Char(9,9) _ "While reader.Next(." _ $$$zNormalizeClassName(refName) _ ", .sc) {" )
                        Do methodDef.Implementation.WriteLine( $Char(9,9,9) _ "Return:$$$ISERR(sc) sc")
                        Do methodDef.Implementation.WriteLine( $Char(9,9,9) _ "Do ..ListOf" _ $$$zNormalizeClassName(refName) _ ".Insert(" _ $$$zNormalizeClassName(refName) _ ")" )
                        Do methodDef.Implementation.WriteLine( $Char(9,9) _ "}" )
                        Do methodDef.Implementation.WriteLine( $Char(9,9) _ "Return sc")
                } Else {
                    Do methodDef.Implementation.WriteLine( $Char(9,9) _ "$$$ThrowStatus($$$ERROR($$$NotImplemented))")
                }
                Do methodDef.Implementation.WriteLine( $Char(9) _ "}")

            }
        }

    }

    Do methodDef.Implementation.WriteLine( $Char(9) _ "Quit sc")

    Set sc = classDef.%Save()
    Quit sc
}

/// Generate Response classes<br/>
Method GenerateGenericResponse() As %Status
{
    #dim sc As %Status = $$$OK
    Set className = ..genericResponseClassName
    #dim cDef As %Dictionary.ClassDefinition
    $$$QuitOnError(##class(dc.openapi.common.Utils).CreateClassDefInstance(className, .cDef))

    ;Set cDef.Super = "%Persistent,Ens.Response"
    Set cDef.Super = ..superGenericResponse
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

    Do cDef.Properties.Insert(property)

    Set methodDef = ##class(%Dictionary.MethodDefinition).%New()
    Set methodDef.Name = "LoadFromResponse"
    Set methodDef.FormalSpec = "httpResponse:%Net.HttpResponse,caller:%String="""""
    Set methodDef.ReturnType = "%Status"
    Do cDef.Methods.Insert(methodDef)
    Do methodDef.Implementation.WriteLine( $Char(9) _ "Set sc = $$$OK")
    Do methodDef.Implementation.WriteLine( $Char(9) _ "Do ..body.CopyFrom(httpResponse.Data)")
    Do methodDef.Implementation.WriteLine( $Char(9) _ "Set ..httpStatusCode = httpResponse.StatusCode")
    Do methodDef.Implementation.WriteLine( $Char(9) _ "Set ..operation = caller")
    Do methodDef.Implementation.WriteLine( $Char(9) _ "Set key = """"")
    Do methodDef.Implementation.WriteLine( $Char(9) _ "For  {")
    Do methodDef.Implementation.WriteLine( $Char(9,9) _ "Set key = $Order(httpResponse.Headers(key), 1, headerValue)")
    Do methodDef.Implementation.WriteLine( $Char(9,9) _ "Quit:key=""""")
    Do methodDef.Implementation.WriteLine( $Char(9,9) _ "Do ..headers.SetAt(headerValue, key)")
    Do methodDef.Implementation.WriteLine( $Char(9) _ "}")
    Do methodDef.Implementation.WriteLine( $Char(9) _ "Quit sc")
    Set sc = cDef.%Save()

    Return sc
}

}
