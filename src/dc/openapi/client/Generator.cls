Class dc.openapi.client.Generator Extends %RegisteredObject
{

Property spec As %DynamicObject;

Property application As %String;

// Property ensemble As %Boolean [ InitialExpression = 1 ];

Property debug As %Boolean [ InitialExpression = {$Get(%zDebug,0)} ];

Property tmp As %Binary [ MultiDimensional ];

Property compile As %Boolean [ InitialExpression = 1 ];

Property ensOperationClassName As %String [ Private ];

Property ensGenericResponseClassName As %String [ Private ];

Property ensProcessClassName As %String [ Private ];

Property UrlMap As %Dictionary.XDataDefinition [ InitialExpression = {##class(%Dictionary.XDataDefinition).%New()} ];

/// To avoid erasing existing code, the generator don't overwrite existing classes.  These classes are skiped.<br/>
/// For generator testing\development purpose, It could be usefull to erase existing classes<br/>
/// Set to true if you wish this behavior or set %zOverwriteIfExist=1 in your process\terminal.
Property overwriteIfExist As %Boolean [ InitialExpression = {+$Get(%zOverwriteIfExist,0)} ];

Method generate() As %Status
{
    Set sc = $$$OK
    TStart 
    
    Try {
        
        If ..spec.swagger '= "2.0" {
            $$$ThrowStatus($$$ERROR(5001,$$$FormatText("Currently this tool support only swagger 2.0 (swagger reached: %1).", ..spec.swagger)))
        } 

        $$$ThrowOnError(..generateEnsembleClasses())
        
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

ClassMethod packageExists(packageName As %String) As %Boolean
{
    Set packageList = ##class(%Dictionary.PackageDefinition).GetPackageList()
    Return ''packageList.Find($zcvt(packageName, "U"))
}

Method generateEnsembleClasses() As %SYSTEM.Status
{
    Set sc = $$$OK
    
    Try {
        Set ..ensOperationClassName = ..application _ ".Operation" 
        Set ..ensGenericResponseClassName = ..application _ ".GenericResponse" 
        Set ..ensProcessClassName = ..application _ ".Process" 


        Set ..UrlMap = ##class(%Dictionary.XDataDefinition).%New()
        Set ..UrlMap.Name = "UrlMap"
        Set ..UrlMap.XMLNamespace = "http://www.intersystems.com/urlmap"
        Do ..UrlMap.Data.WriteLine("<Routes>")

        $$$ThrowOnError(..ensGenericResponse())
        $$$ThrowOnError(..ensOperationClass())
        $$$ThrowOnError(..restProxy())


        Set iter = ..spec.paths.%GetIterator()
        While iter.%GetNext(.serviceLocation , .value ) {

            Set %zCurrentData("ServiceLocation") = serviceLocation
            
            Set methodIter = value.%GetIterator()
            While methodIter.%GetNext(.method , .serviceDefinition ) {
            
                Set %zCurrentData("method") = method
            
                $$$ThrowOnError(..ensRequestClass(serviceDefinition, value))
                $$$ThrowOnError(..ensServiceClass(serviceDefinition))
                $$$ThrowOnError(..ensOperationMethod(serviceDefinition))
                
                Set routeUrl = $Translate(serviceLocation, "{}", ":")
                Do ..UrlMap.Data.WriteLine($$$FormatText("<Route Url=""%1"" Method=""%2"" Call=""%3""/>", routeUrl, $Zcvt(method,"U"), $Zcvt(method,"U")_serviceDefinition.operationId))
                $$$ThrowOnError(..restProxyMethod(serviceDefinition))
            }
        
        }
        ;Set ..tmp("RQPARAMETERS", $Zcvt(%zCurrentData("method"),"U"), serviceDefinition.operationId, in, parameterName) = propertyName
        ;<Route Url="/launchProcess/:processName" Method="POST" Call="launchProcess"/>

        Do ..UrlMap.Data.WriteLine("</Routes>")
        
        
        $$$ThrowOnError(..ensProxyService())
        $$$ThrowOnError(..messageMap())
        $$$ThrowOnError(..ensProcessClass())
        $$$ThrowOnError(..ensProduction())
        
        
        $$$ThrowOnError(..restProxyURLMAP())
       
        If ..compile {
            Set sc = $system.OBJ.Compile(..ensOperationClassName ,"ck")
        }
    } Catch(ex) {
        Set sc = ex.AsStatus()
    }

    Return sc
}

Method restProxy() As %Status
{
    #dim sc As %Status = $$$OK
    Set restClassname = ..application _ ".REST"
    ;Set ..tmp("SERVICES",restClassname)=""
    
    #dim cDef As %Dictionary.ClassDefinition
    If ##class(%Dictionary.ClassDefinition).%ExistsId(restClassname) {
       Return $$$OK
    } Else {
        Set cDef = ##class(%Dictionary.ClassDefinition).%New(restClassname)
    }

    Set utilsClass =..application_".Utils"
    If '$Data(^oddDEF(utilsClass)) {
        Merge ^oddDEF(utilsClass) = ^oddDEF("dc.openapi.client.Utils")
        Set ^oddDEF(utilsClass, 1) = ..application_".Utils"
        $$$ThrowOnError($SYSTEM.OBJ.Compile(utilsClass,"ck"))
    }

    Set projectionClassName = ..application _ ".Projection"
    #dim projectionClass As %Dictionary.ClassDefinition = ##class(%Dictionary.ClassDefinition).%New(projectionClassName)
    Set projectionClass.Super = "%Projection.AbstractProjection"


    Set cDef.Super = "%CSP.REST"
    Set cDef.Inheritance = "left"

    #dim projection As %Dictionary.ProjectionDefinition = ##class(%Dictionary.ProjectionDefinition).%New()
    Set projection.Name = "WebApp"
    Set projection.Type = projectionClassName
    Do cDef.Projections.Insert(projection)

    #dim mDef As %Dictionary.MethodDefinition = ##class(%Dictionary.MethodDefinition).%New()
    Set mDef.Name = "CreateProjection"
    Set mDef.FormalSpec = "cls:%String,&params"
    Set mDef.ClassMethod = 1
    Do mDef.Implementation.WriteLine($c(9)_ "Return ..%CreateWebApplication()")
    Set mDef.ReturnType = "%Status"
    Do projectionClass.Methods.Insert(mDef)

    Set mDef = ##class(%Dictionary.MethodDefinition).%New()
    Set mDef.Name = "RemoveProjection"
    Set mDef.FormalSpec = "cls:%String,&params,recompile:%Boolean"
    Set mDef.ClassMethod = 1
    Do mDef.Implementation.WriteLine($c(9)_ "Return $$$OK")
    Set mDef.ReturnType = "%Status"
    Do projectionClass.Methods.Insert(mDef)

    Set mDef = ##class(%Dictionary.MethodDefinition).%New()
    Set mDef.Name = "%CreateWebApplication"

    Set restAppName = "/"_$zcvt($tr(..application,"."),"l")_"rest"
    Do mDef.Implementation.WriteLine($Char(9)_"Set oldNs = $namespace")
    Do mDef.Implementation.WriteLine($Char(9)_"Zn ""%SYS""")
    Do mDef.Implementation.WriteLine($Char(9)_"if ##class(Security.Applications).Exists("""_restAppName_""") { Zn oldNs  Return $$$OK }" )
    Do mDef.Implementation.WriteLine($Char(9)_"write ""Create web application ..."",!")
    Do mDef.Implementation.WriteLine($Char(9)_"set webName = """_restAppName_"""")
    Do mDef.Implementation.WriteLine($Char(9)_"set webProperties(""NameSpace"") = oldNs")
    Do mDef.Implementation.WriteLine($Char(9)_"set webProperties(""Enabled"") = 1")
    Do mDef.Implementation.WriteLine($Char(9)_"set webProperties(""CSPZENEnabled"") = 1")
    Do mDef.Implementation.WriteLine($Char(9)_"set webProperties(""AutheEnabled"") = 64")
    Do mDef.Implementation.WriteLine($Char(9)_"set webProperties(""iKnowEnabled"") = 1")
    Do mDef.Implementation.WriteLine($Char(9)_"set webProperties(""DeepSeeEnabled"") = 1")
    Do mDef.Implementation.WriteLine($Char(9)_"Set webProperties(""DispatchClass"")="""_restClassname_"""")
    Do mDef.Implementation.WriteLine($Char(9)_"Set webProperties(""MatchRoles"")="":%DB_IRISAPP""")
    Do mDef.Implementation.WriteLine($Char(9)_"set sc = ##class(Security.Applications).Create(webName, .webProperties)")
    Do mDef.Implementation.WriteLine($Char(9)_"write !,""Web application creation status "", $SYSTEM.Status.GetOneErrorText(sc),! ")
    Do mDef.Implementation.WriteLine($Char(9)_"Zn oldNs")
    Do mDef.Implementation.WriteLine($Char(9)_"Return $$$OK")
   
    Set mDef.ClassMethod = 1
    Do projectionClass.Methods.Insert(mDef)
    
    $$$ThrowOnError(projectionClass.%Save())
    If ..compile {
        $$$ThrowOnError($SYSTEM.OBJ.Compile(projectionClassName,"ck"))
    }

    
    Return cDef.%Save()
}

Method restProxyMethod(serviceDefinition As %Library.DynamicObject) As %Status
{
    Set sc = $$$OK
    Set ensRequestClassName = ..application _ "." _ serviceDefinition.operationId _ "Request"
    Set utilsClass =..application_".Utils"
    Set pList = $lfs(..tmp("ensRequest", ensRequestClassName, "REQUESTPARAMLOCATION"),","), ptr = 0
    
    Set restClassname = ..application _ ".REST"
    Set cDef = ##class(%Dictionary.ClassDefinition).%OpenId(restClassname)

    Set mDef = ##class(%Dictionary.MethodDefinition).%New()
    Set mDef.Name = $Zcvt(%zCurrentData("method"),"U")_serviceDefinition.operationId
    Set mDef.Description = $Replace(serviceDefinition.description, $$$NL, "<br/>"_$$$NL)
    Set mDef.FormalSpec = ""
    Set mDef.ReturnType = "%Status"
    Set mDef.ClassMethod = 1

    Do mDef.Implementation.WriteLine($Char(9)_$Replace("Set ensRequest = ##class(%1).%New()", "%1", ensRequestClassName))
    Do mDef.Implementation.WriteLine($Char(9)_"Set ensRequest.consume = %request.ContentType")
    Do mDef.Implementation.WriteLine($Char(9)_"Set ensRequest.accept = $Get(%request.CgiEnvs(""HTTP_ACCEPT""),""*/*"")")
    

    While $Listnext(pList, ptr, propertyInfo) {            

        Set propertyName = $Piece(propertyInfo, ":", 1)
        Set in = $Piece(propertyInfo, ":", 2)
        Set parameterName = $Piece(propertyInfo, ":", 3)
        Set paramType = $Piece(propertyInfo, ":", 4)


        If in = "query" {
            Set line = "Set ensRequest.%1 = $Get(%request.Data(""%2"",1))"
            Do mDef.Implementation.WriteLine($Char(9)_$$$FormatText(line, propertyName, parameterName))
        } ElseIf in = "path" {
            Set line = "Set ensRequest.%1 = %2"
            Do mDef.Implementation.WriteLine($Char(9)_$$$FormatText(line, propertyName, parameterName))
            Set mDef.FormalSpec = mDef.FormalSpec_","_parameterName_":%String"
        } ElseIf (in = "header") &&(parameterName'="accept") {    
            Set line = "Set ensRequest.%1 = $Get(%request.CgiEnvs(""%2""))"
            Do mDef.Implementation.WriteLine($Char(9)_$$$FormatText(line, propertyName, parameterName))

        } ElseIf in = "formData" {
            Set line = "set mime = %request.GetMimeData(""%1"")"
            Do mDef.Implementation.WriteLine($Char(9)_$$$FormatText(line, parameterName))
            Set line = "If $Isobject(mime) { Do ensRequest.%1.CopyFrom(mime) } Else {} " ; MayBe missing something here.
            Do mDef.Implementation.WriteLine($Char(9)_$$$FormatText(line, propertyName))
            
        } ElseIf in = "body" {
            Set line = "Do ensRequest.%1.CopyFrom(%request.Content)"
            Do mDef.Implementation.WriteLine($Char(9)_$$$FormatText(line, propertyName))
        }


       
    }
    Set mDef.FormalSpec = $Extract(mDef.FormalSpec, 2, *)
    

    Do mDef.Implementation.WriteLine($Char(9)_$$$FormatText("Return ##class(%1).invokeHostAsync(""%2"", ensRequest, ""%3"")", utilsClass, ..ensProcessClassName, ..application_".ProxyService"))

    Do cDef.Methods.Insert(mDef)

    Return cDef.%Save()
}

Method restProxyURLMAP(serviceDefinition As %Library.DynamicObject) As %Status
{
    Set sc = $$$OK, restClassname =..application _ ".REST"
    Set cDef = ##class(%Dictionary.ClassDefinition).%OpenId(..application _ ".REST")
    Set cDef.Super = "%CSP.REST"
    Do cDef.XDatas.Insert(..UrlMap)
    $$$ThrowOnError(cDef.%Save())
    If ..compile {
        Set sc = $system.OBJ.Compile(restClassname,"ck")
    }
    Return sc
}

Method ensOperationMethod(serviceDefinition As %Library.DynamicObject) As %Status
{
    Set sc = $$$OK

    Set methodName = $Zcvt(%zCurrentData("method"),"U")_serviceDefinition.operationId
    Set ensOperationClassName = ..ensOperationClassName

    If ##class(%Dictionary.MethodDefinition).%ExistsId(ensOperationClassName_"||"_methodName) {
        If '..overwriteIfExist {
            Write:..debug !,"Method ", methodName, " already exists, Method skipped"
        } Else {
            Do ##class(%Dictionary.MethodDefinition).%DeleteId(ensOperationClassName_"||"_methodName)
        }
    }
    
    Set cDef = ##class(%Dictionary.ClassDefinition).%OpenId(ensOperationClassName,,.sc)
    Return:$$$ISERR(sc) sc

    Set ensRequestClassName = ..application _ "." _ serviceDefinition.operationId _ "Request"

    
    Set ..tmp("MessageMap","MessageType", ensRequestClassName) = methodName

    Set mDef = ##class(%Dictionary.MethodDefinition).%New()
    Set mDef.Name = methodName
    Set mDef.Description = $Replace(serviceDefinition.description, $$$NL, "<br/>"_$$$NL)
    Set mDef.FormalSpec = $$$FormatText("pRequest:%1,pResponse:%2", ensRequestClassName, "Ens.Response")
    Set mDef.ReturnType = "%Status"
    
    
    Do mDef.Implementation.WriteLine($Char(9) _"Set pURL = """ _ ..spec.basePath _ %zCurrentData("ServiceLocation") _"""")
    Set pList = $lfs(..tmp("ensRequest", ensRequestClassName, "REQUESTPARAMLOCATION"),","), ptr = 0
    Set mParts = $$$NO
    Do mDef.Implementation.WriteLine($Char(9) _ "Set pHttpRequestIn = ##class(%Net.HttpRequest).%New()")
    Do mDef.Implementation.WriteLine($Char(9) _ "Set pHttpRequestIn.ContentType = pRequest.consume")
    While $Listnext(pList, ptr, propertyInfo) {
        
        Set propertyName = $Piece(propertyInfo, ":", 1)
        Set in = $Piece(propertyInfo, ":", 2)
        Set parameterName = $Piece(propertyInfo, ":", 3)
        Set paramType = $Piece(propertyInfo, ":", 4)

        Set ..tmp("RQPARAMETERS", $Zcvt(%zCurrentData("method"),"U"), serviceDefinition.operationId, in, parameterName) = propertyName

        If in = "query" {
            Do mDef.Implementation.WriteLine($Char(9) _ "Do pHttpRequestIn.SetParam(""" _ parameterName _ """, pRequest." _ propertyName _")")
        } ElseIf in = "path" {
            Do mDef.Implementation.WriteLine($Char(9) _ "Set pURL = $Replace(pURL, ""{"_parameterName_"}"", pRequest." _ propertyName _ ")" )
        } ElseIf in = "header" {
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
            If paramType [ "%Stream" {

                Do mDef.Implementation.WriteLine($Char(9) _ "Do pRequest."_propertyName_".Rewind()")
                Do mDef.Implementation.WriteLine($Char(9) _ "While 'pRequest."_propertyName_".AtEnd {")
                Do mDef.Implementation.WriteLine($Char(9,9) _"Do pHttpRequestIn.EntityBody.Write(pRequest."_propertyName_".Read())")
                Do mDef.Implementation.WriteLine($Char(9) _ "}")
                
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

    Do mDef.Implementation.WriteLine($Char(9) _ "Set sc = ..Adapter.SendFormDataArray(.pHttpResponse, """_ %zCurrentData("method") _""", pHttpRequestIn , , , pURL)")
    Do mDef.Implementation.WriteLine($Char(9) _ $$$FormatText("Set pResponse = ##class(%1).%New()",..ensGenericResponseClassName))
    Do mDef.Implementation.WriteLine($Char(9) _ "Do ..genericProcessResponse(pRequest, pResponse, ""POSTaddPet"", sc, $Get(pHttpResponse))")
    Do mDef.Implementation.WriteLine($Char(9) _ "Return sc")
    Do cDef.Methods.Insert(mDef)

    Return cDef.%Save()
}

Method messageMap() As %Status
{
    Set cDef = ##class(%Dictionary.ClassDefinition).%OpenId(..ensOperationClassName,,.sc)

    Return:$$$ISERR(sc) sc
    
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

Method ensOperationClass() As %Status [ Private ]
{
    Set sc = $$$OK
    Set ensOperationClassName = ..ensOperationClassName
    If $Data(^oddDEF(ensOperationClassName)) && '..overwriteIfExist {
        Write:..debug !,ensOperationClassName, " already exists, class skipped"
        Return $$$OK
    } Else {
        Kill ^oddDEF(ensOperationClassName)
    }

    Set cDef = ##class(%Dictionary.ClassDefinition).%New(ensOperationClassName)
    Set cDef.Super = "Ens.BusinessOperation"

    Set property = ##class(%Dictionary.PropertyDefinition).%New()
    Set property.Name = "Adapter"
    Set property.Type = "EnsLib.HTTP.OutboundAdapter"
    Do cDef.Properties.Insert(property)

    Set classParameter = ..createClassParameter("ADAPTER", "EnsLib.HTTP.OutboundAdapter")
    Do cDef.Parameters.Insert(classParameter)


    Set mDef = ##class(%Dictionary.MethodDefinition).%New()
    Set mDef.Name = "genericProcessResponse"
    Set mDef.FormalSpec = $$$FormatText("pRequest:%1,pResponse:%2,caller:%String,status:%Status,pHttpResponse:%Net.HttpResponse", "Ens.Request", ..application_".GenericResponse")
    Set mDef.ReturnType = "%Status"

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
    Do mDef.Implementation.WriteLine($Char(9) _"}")
    Do mDef.Implementation.WriteLine($Char(9) _"Return sc")
    
    Do cDef.Methods.Insert(mDef)
    Set sc = cDef.%Save()

	Return sc
}

Method ensGenericResponse() As %Status
{
    Set sc = $$$OK
    Set genericResponseClassName = ..ensGenericResponseClassName

    If $Data(^oddDEF(genericResponseClassName)) && '..overwriteIfExist {
        Write !,genericResponseClassName, " already exists, class skipped"
        Return $$$OK
    } Else {
        Kill ^oddDEF(genericResponseClassName)
    }

    Set cDef = ##class(%Dictionary.ClassDefinition).%New(genericResponseClassName)
    Set cDef.Super = "%Persistent,Ens.Response"
    Set cDef.Inheritance = "left"

    Set property = ##class(%Dictionary.PropertyDefinition).%New()
    Set property.Name = "httpStatusCode"
    Set property.Type = "%Integer"
    Do cDef.Properties.Insert(property)

    Set property = ##class(%Dictionary.PropertyDefinition).%New()
    Set property.Name = "headers"
    Set property.Type = "%String"
    Set property.Collection = "array"
    Do cDef.Properties.Insert(property)

    Set property = ##class(%Dictionary.PropertyDefinition).%New()
    Set property.Name = "body"
    Set property.Type = "%Stream.GlobalBinary"
    Do cDef.Properties.Insert(property)

    Set property = ##class(%Dictionary.PropertyDefinition).%New()
    Set property.Name = "operation"
    Set property.Type = "%Stream.GlobalBinary"
    Do cDef.Properties.Insert(property)

    Set property = ##class(%Dictionary.PropertyDefinition).%New()
    Set property.Name = "operationStatusText"
    Set property.Type = "%String"
    Do cDef.Properties.Insert(property)
    
    $$$ThrowOnError(cDef.%Save())

    If ..compile {
        Set sc = $SYSTEM.OBJ.Compile(genericResponseClassName,"ck")
    }

    Return sc
}

Method ensProxyService() As %Status
{
    #dim sc As %Status = $$$OK
    
    Set serviceClassName = ..application _ ".ProxyService"
    Set ..tmp("SERVICES",serviceClassName)=""
    
    If $Data(^oddDEF(serviceClassName)) && '..overwriteIfExist {
        Write:..debug !,serviceClassName, " already exists, class skipped"
        Return $$$OK
    } Else {
        Kill ^oddDEF(serviceClassName)
    }
    Set cDef = ##class(%Dictionary.ClassDefinition).%New(serviceClassName)
    Set cDef.Super = "Ens.BusinessService"

    $$$TOE(sc, cDef.%Save())
    If ..compile {
        Set sc = $system.OBJ.Compile(serviceClassName,"ck")
    }
    
    Return sc
}

Method ensServiceClass(serviceDefinition As %Library.DynamicObject) As %Status [ Private ]
{
    Set sc = $$$OK

    Set serviceClassName = ..application _ "." _ serviceDefinition.operationId _ "Service"
    
    Set ..tmp("SERVICES",serviceClassName)=""

    If $Data(^oddDEF(serviceClassName)) && '..overwriteIfExist {
        Write:..debug !,serviceClassName, " already exists, class skipped"
        Return $$$OK
    } Else {
        Kill ^oddDEF(serviceClassName)
    }

    

    Set ensRequestClassName = ..application _ "." _ serviceDefinition.operationId _ "Request"
    Set ensOperationClassName = ..ensOperationClassName
    

    Set cDef = ##class(%Dictionary.ClassDefinition).%New(serviceClassName)
    Set cDef.Super = "Ens.BusinessService"


    Set property = ##class(%Dictionary.PropertyDefinition).%New()
    Set property.Name = "Adapter"
    Set property.Type = "Ens.Adapter"
    Set property.Description = "Auto generated : Change by your Adapter type."
    Do cDef.Properties.Insert(property)

    Set classParameter = ..createClassParameter("ADAPTER", "Ens.Adapter")
    Set classParameter.Description = "Auto generated : Change by your Adapter type."
    Do cDef.Parameters.Insert(classParameter)


    Set mDef = ##class(%Dictionary.MethodDefinition).%New()
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

    $$$TOE(sc, cDef.%Save())
    If ..compile {
        Set sc = $system.OBJ.Compile(serviceClassName,"ck")
    }
    Return sc
}

Method ensRequestClass(serviceDefinition As %Library.DynamicObject, value As %Library.DynamicObject) As %Status [ Private ]
{
    Set sc = $$$OK
    Set className = ..application _ "." _ serviceDefinition.operationId _ "Request"
    

    If $Data(^oddDEF(className)) && '..overwriteIfExist {
        Write:..debug !,className, " already exists, class skipped"
        Return $$$OK
    } Else {
        Kill ^oddDEF(className)
    }

    Set cDef = ##class(%Dictionary.ClassDefinition).%New(className)
    Set cDef.Description = "Request Object for application : "_..application _ $$$NL_"<br/>"
                            _ "Service : "_serviceDefinition.operationId

    ;If ..ensemble {
        Set cDef.Super = "%Persistent,Ens.Request"
        Set cDef.Inheritance = "left"
    ;}
    
    /* consume property */
    Set property = ##class(%Dictionary.PropertyDefinition).%New()
    Set property.Name = "consume"
    Set property.Type = "%String"
    Set description = ""
    If serviceDefinition.consumes '= "" {
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

    ;Set requestParamLocation = "consume:header"

    /* accept property */

    Set producesObject = ""
    If serviceDefinition.produces '= "" {
        Set producesObject = serviceDefinition.produces
    } ElseIf ..spec.produces '= "" {
        Set producesObject = ..spec.produces
    }
    Set property = ##class(%Dictionary.PropertyDefinition).%New()
    Set property.Name = "accept"
    Set property.Type = "%String"
    Set description=""
    If producesObject '= "" {
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

    ;Set requestParamLocation = requestParamLocation _ ",accept:header:accept:%String"
    Set requestParamLocation =  "accept:header:accept:%String"
    
    /* All parameters*/
    
    Set parametersObject = ""
    If serviceDefinition.parameters '= "" {
        Set parametersObject = serviceDefinition.parameters
    } ElseIf value.parameters '= "" {
        Set parametersObject = value.parameters
    }

    If parametersObject '= "" {
        Set iterParam = parametersObject.%GetIterator()
        
        While iterParam.%GetNext(.keyParam, .parameter) {
            Set property = ##class(%Dictionary.PropertyDefinition).%New()
            Set property.Name = parameter.in _ $Tr(parameter.name, "_", "")
            Set property.Type = ..getObjectScriptType(parameter.type, parameter.in)
            Set property.Required = parameter.required

            
            Set:parameter.description'="" property.Description =  $Replace(parameter.description, $$$NL, "<br/>" _ $$$NL )
            Do cDef.Properties.Insert(property)

            Set requestParamLocation = requestParamLocation _ "," _ property.Name _ ":" _ parameter.in _ ":" _ parameter.name _ ":" _ property.Type

        }
        Set keyParam = ""
    }
    
    Set ..tmp("ensRequest", className, "REQUESTPARAMLOCATION") = requestParamLocation

    $$$TOE(sc, cDef.%Save())
    
    If ..compile { 
        Set sc = $system.OBJ.Compile(className,"ck")
    }
    
    Return sc
}

Method ensProcessClass() As %Status
{
    Set sc = $$$OK
    
    If $Data(^oddDEF(..ensProcessClassName)) && '..overwriteIfExist {
        Write:..debug !,..ensProcessClassName, " already exists, class skipped"
        Return $$$OK
    } Else {
        Kill ^oddDEF(..ensProcessClassName)
    }

    Set cDef = ##class(%Dictionary.ClassDefinition).%New(..ensProcessClassName)
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

    Set sc = cDef.%Save()

    If ..compile {
        Set sc = $SYSTEM.OBJ.Compile(..ensProcessClassName, "ck")
    }

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

ClassMethod getObjectScriptType(OpenApiType As %String, in As %String = "") As %String
{
    If in = "body"  Return "%Stream.GlobalBinary"
    If OpenApiType = "integer" Return "%Integer"
    If OpenApiType = "long" Return "%Integer"
    If OpenApiType = "float" Return "%Numeric"
    If OpenApiType = "double" Return "%Double"
    If OpenApiType = "string" Return "%String"
    If OpenApiType = "byte" Return "%Stream.GlobalBinary"
    If OpenApiType = "binary" Return "%Stream.GlobalBinary"
    If OpenApiType = "file" Return "%Stream.GlobalBinary"
    If OpenApiType = "boolean" Return "%Boolean"
    If OpenApiType = "date" Return "%String" ;--> 2020-06-13
    If OpenApiType = "dateTime" Return "%String" ;--> 2020-06-13 https://xml2rfc.tools.ietf.org/public/rfc/html/rfc3339.html#anchor14
    If OpenApiType = "password" Return "%String" ;--> 2020-06-13
    Return "%String"
}

Method createClassParameter(name As %String, value As %String) As %Dictionary.ParameterDefinition
{
    Set classParameter = ##class(%Dictionary.ParameterDefinition).%New()
    Set classParameter.Name = name
    Set classParameter.Default = value
    Return classParameter
}

Method ensProduction() As %Status
{
    Set sc = $$$OK
    Set productionClassName = ..application_".Production"

    If $Data(^oddDEF(productionClassName)) && '..overwriteIfExist {
        Write:..debug !,productionClassName, " already exists, class skipped"
        Return $$$OK
    } Else {
        Kill ^oddDEF(productionClassName)
    }

    Set strServiceTemplate = "<Item Name=""{className}"" Category="""" ClassName=""{className}"" PoolSize=""1"" Enabled=""false"" Foreground=""false"" Comment="""" LogTraceEvents=""false"" Schedule=""""></Item>"

    Set className = ""
    For  {
        Set className = $Order(..tmp("SERVICES",className))
        Quit:className=""
        Set service($Increment(service)) = $Replace(strServiceTemplate, "{className}", className)
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
            Set line = $Replace(line, "{server}", ..spec.host)
            Set line = $Replace(line, "{SSLConfig}", "default")
            Do xData.Data.WriteLine(line)
        }
    }

    Set cDef = ##class(%Dictionary.ClassDefinition).%New(productionClassName)
    Set cDef.Super = "Ens.Production"
    Do cDef.XDatas.Insert(xData)

    $$$ThrowOnError(cDef.%Save())

    If ..compile {
        Set sc = $SYSTEM.OBJ.Compile(productionClassName, "ck")
    }

    Return sc
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
  </Item>
  <Item Name="{ensProcessClassName}" Category="" ClassName="{ensProcessClassName}" PoolSize="1" Enabled="true" Foreground="false" Comment="" LogTraceEvents="false" Schedule="">
  </Item>
</Production>
}

}
