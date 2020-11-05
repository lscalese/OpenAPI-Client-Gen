Class dc.openapi.client.Generator Extends %RegisteredObject
{

Property spec As %DynamicObject;

Property application As %String;

// Property ensemble As %Boolean [ InitialExpression = 1 ];

Property debug As %Boolean [ InitialExpression = {$Get(%zDebug,0)} ];

Property tmp As %Binary [ MultiDimensional ];

Property compile As %Boolean [ InitialExpression = 1 ];

/// To avoid erasing existing code, the generator don't overwrite existing classes.  These classes are skiped.<br/>
/// For generator testing\development purpose, It could be usefull to erase existing classes<br/>
/// Set to true if you wish this behavior or set %zOverwriteIfExist=1 in your process\terminal.
Property overwriteIfExist As %Boolean [ InitialExpression = {+$Get(%zOverwriteIfExist,0)} ];

Method generate() As %Status
{
    Set sc = $$$OK
    TStart 
    
    Try {
   
        $$$TOE(sc, ..generateEnsembleClasses())
        
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
        Set ensOperationClassName = ..application _ ".Operation" 

        $$$ThrowOnError(..ensOperationClass(ensOperationClassName))

        Set iter = ..spec.paths.%GetIterator()
        While iter.%GetNext(.serviceLocation , .value ) {

            Set %zCurrentData("ServiceLocation") = serviceLocation
            
            Set methodIter = value.%GetIterator()
            While methodIter.%GetNext(.method , .serviceDefinition ) {
            
                Set %zCurrentData("method") = method
            
                $$$ThrowOnError(..ensRequestClass(serviceDefinition, value))
                $$$ThrowOnError(..ensServiceClass(serviceDefinition))
                $$$ThrowOnError(..ensOperationMethod(serviceDefinition, ensOperationClassName))
                
            }
        
        }
        
        $$$ThrowOnError(..messageMap(ensOperationClassName))

        If ..compile {
            Set sc = $system.OBJ.Compile(..application _ ".Operation" ,"ck")
        }
    } Catch(ex) {
        Set sc = ex.AsStatus()
    }

    Return sc
}

Method ensOperationMethod(serviceDefinition As %Library.DynamicObject, ensOperationClassName As %String = {..application _ ".Operation"}) As %Status
{
    Set sc = $$$OK

    Set cDef = ##class(%Dictionary.ClassDefinition).%OpenId(ensOperationClassName,,.sc)

    Return:$$$ISERR(sc) sc

    Set ensRequestClassName = ..application _ "." _ serviceDefinition.operationId _ "Request"

    Set methodName = $Zcvt(%zCurrentData("method"),"U")_serviceDefinition.operationId

    Set mDef = ##class(%Dictionary.MethodDefinition).%New()
    Set mDef.Name = methodName
    ;Set mDef.Description = "Auto generated method"
    Set mDef.Description = $Replace(serviceDefinition.description, $$$NL, "<br/>"_$$$NL)
    Set mDef.FormalSpec = $$$FormatText("pRequest:%1,pResponse:%2", ensRequestClassName, "Ens.Response")
    Set mDef.ReturnType = "%Status"
    ;Do mDef.Implementation.WriteLine($Char(9) _ "; Auto generated, put your own code...")
    
    Do mDef.Implementation.WriteLine($Char(9) _"Set pURL = """ _ ..spec.basePath _ %zCurrentData("ServiceLocation") _"""")
    Set pList = $lfs(..tmp("ensRequest", ensRequestClassName, "REQUESTPARAMLOCATION"),","), ptr = 0
    Set mParts = $$$NO
    ;pHttpRequestIn
    Do mDef.Implementation.WriteLine($Char(9) _ "Set pHttpRequestIn = ##class(%Net.HttpRequest).%New()")
    Do mDef.Implementation.WriteLine($Char(9) _ "Set pHttpRequestIn.ContentType = pRequest.consume")
    While $Listnext(pList, ptr, propertyInfo) {
        
        Set propertyName = $Piece(propertyInfo, ":", 1)
        Set in = $Piece(propertyInfo, ":", 2)
        Set parameterName = $Piece(propertyInfo, ":", 3)
        Set paramType = $Piece(propertyInfo, ":", 4)

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
        Do mDef.Implementation.WriteLine($Char(9) _"If ISOBJECT($Get(mParts)) {")
        Do mDef.Implementation.WriteLine($Char(9,9) _"Set mimeWriter = ##class(%Net.MIMEWriter).%New()")
        Do mDef.Implementation.WriteLine($Char(9,9) _"Do mimeWriter.OutputToStream(.stream)")
        Do mDef.Implementation.WriteLine($Char(9,9) _"Do mimeWriter.WriteMIMEBody(mParts)")
        Do mDef.Implementation.WriteLine($Char(9,9) _"Set pHttpRequestIn.EntityBody = stream")
        Do mDef.Implementation.WriteLine($Char(9,9) _"Set pHttpRequestIn.ContentType = ""multipart/form-data; boundary="" _ mParts.Boundary")
        Do mDef.Implementation.WriteLine($Char(9) _"}")
    }

    Do mDef.Implementation.WriteLine($Char(9) _ "Set sc = ..Adapter.SendFormDataArray(.pHttpResponse, """_ %zCurrentData("method") _""", pHttpRequestIn , , , pURL)")
    Do mDef.Implementation.WriteLine($Char(9) _ "If $$$ISOK(sc) {")
    Do mDef.Implementation.WriteLine($Char(9,9) _ "Set logMsg = pHttpResponse.StatusCode_"" ""_pHttpResponse.ReasonPhrase")
    Do mDef.Implementation.WriteLine($Char(9,9) _ "If pHttpResponse.StatusCode = 200 { $$$LOGINFO(logMsg) } Else { $$$LOGERROR(logMsg) }")
    Do mDef.Implementation.WriteLine($Char(9) _ "} Else {$$$LOGSTATUS(sc)} ")
    Do mDef.Implementation.WriteLine($Char(9) _ "Return sc")

    Do cDef.Methods.Insert(mDef)

    $$$ThrowOnError( cDef.%Save() )

    Set ..tmp("MessageMap","MessageType", ensRequestClassName) = methodName

    Return sc
}

Method messageMap(ensOperationClassName As %String) As %Status
{
    Set cDef = ##class(%Dictionary.ClassDefinition).%OpenId(ensOperationClassName,,.sc)

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

Method ensOperationClass(ensOperationClassName As %String) As %Status [ Private ]
{
    Set sc = $$$OK
    
    If $Data(^oddDEF(ensOperationClassName)) && '..overwriteIfExist {
        Write !,ensOperationClassName, " already exists, class skipped"
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

    Set sc = cDef.%Save()

    Return sc
}

Method ensServiceClass(serviceDefinition As %Library.DynamicObject) As %Status [ Private ]
{
    Set sc = $$$OK

    Set serviceClassName = ..application _ "." _ serviceDefinition.operationId _ "Service"
    
    If $Data(^oddDEF(serviceClassName)) && '..overwriteIfExist {
        Write !,serviceClassName, " already exists, class skipped"
        Return $$$OK
    } Else {
        Kill ^oddDEF(serviceClassName)
    }

    Set ensRequestClassName = ..application _ "." _ serviceDefinition.operationId _ "Request"
    Set ensOperationClassName = ..application _ ".Operation"
    

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

    Do mDef.Implementation.WriteLine($Char(9) _ "Return ..SendRequestAsync("""_ensOperationClassName_""", msg)")
    
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
        Write !,className, " already exists, class skipped"
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

/*
Method generateSimpleClient() As %Status
{
    Set sc = $$$OK

    Set clientClass = ..application _ ".client"
    Kill ^oddDEF(clientClass)
    ;Do $system.OBJ.Delete(clientClass, "-d")

    Set cDef=##class(%Dictionary.ClassDefinition).%New(clientClass)
    Set cDef.Super = "dc.openapi.client.Abstract"
    Set cDef.ProcedureBlock=1
    
    Set server = ..createClassParameter("SERVER", $Piece(..spec.host,":"))
    $$$TOE(sc, cDef.Parameters.Insert(server))

    Set port = ..createClassParameter("PORT", $Piece(..spec.host, ":", 2))
    $$$TOE(sc, cDef.Parameters.Insert(port))

    Set basePath = ..createClassParameter("BASEPATH", ..spec.basePath)
    $$$TOE(sc, cDef.Parameters.Insert(basePath))

    If $Isobject(..spec.info) {
        Set cDef.Description = ..spec.info.title _ $$$NL _ "<br/>" 
                                _ "Version: " _ ..spec.info.version _ $$$NL _ "<br/>" 
                                _ $Replace(..spec.info.description, $$$NL, $$$NL_"<br/>")
    }

    Set iter = ..spec.paths.%GetIterator()
    While iter.%GetNext(.serviceLocation , .value ) {
        

        Set methodIter = value.%GetIterator()
        While methodIter.%GetNext(.method , .serviceDefinition ) {
            
            Set mDef = ##class(%Dictionary.MethodDefinition).%New()
            Set mDef.Name = serviceDefinition.operationId
            
            Set mDef.Description = $Replace(serviceDefinition.description, $$$NL, "<br/>"_$$$NL)
            
            Set code = $Char(9) _ "Do ..clean()"
            Do mDef.Implementation.WriteLine(code)


            Set producesObject = ""
            Set acceptDefault = ""
            If serviceDefinition.produces '= "" {
                Set producesObject = serviceDefinition.produces
            } ElseIf ..spec.produces '= "" {
                Set producesObject = ..spec.produces
            }

            If producesObject '="" {
                Set producesList = $lfs($Translate(producesObject.%ToJSON(), "[]""",""),","), ptr = 0
                Set mDef.Description =  mDef.Description _ "<br/><br/>" _ $$$NL _ "accept : <ul>" _ $$$NL
                While $Listnext(producesList,ptr,acc) {
                    Set:acceptDefault="" acceptDefault = acc
                    Set mDef.Description =  mDef.Description _"<li>"_acc_"</li>" _ $$$NL
                }

                Set mDef.Description =  mDef.Description _"</ul>"

            }
            Set mDef.FormalSpec="accept:%String=""" _ acceptDefault _""""
            
            Set code = $Char(9) _ "Do:accept'="""" ..setParameter(""accept"",""header"",""string"",accept)"
            Do mDef.Implementation.WriteLine(code)


            Set consumesObject = serviceDefinition.consumes
            Set consumeDefault = ""
            If consumesObject '= "" {
                Set consumesList = $lfs($Translate(consumesObject.%ToJSON(), "[]""",""),","), ptr = 0
                Set mDef.Description =  mDef.Description _ "<br/><br/>" _ $$$NL _ "consume : <ul>" _ $$$NL
                While $Listnext(consumesList,ptr,mimeP) {
                    Set:consumeDefault="" consumeDefault = mimeP
                    Set mDef.Description =  mDef.Description _"<li>"_mimeP_"</li>" _ $$$NL
                }

                Set mDef.Description =  mDef.Description _"</ul>"
            }

            Set mDef.FormalSpec=mDef.FormalSpec _ ",consume:%String="""_consumeDefault_""""

            Set parametersObject = ""
            
            If serviceDefinition.parameters '= "" {
                Set parametersObject = serviceDefinition.parameters
            } ElseIf value.parameters '= "" {
                Set parametersObject = value.parameters
            }

            Set code = $Char(9) _ "Set:consume'="""" ..request.ContentType = consume"
            Do mDef.Implementation.WriteLine(code)

            If parametersObject '= "" {
                Set iterParam = parametersObject.%GetIterator()
                
                While iterParam.%GetNext(.keyParam, .parameter) {

                    Set parameterMethodName = parameter.in _ $Tr(parameter.name, "_", "")
                    Set mDef.FormalSpec = mDef.FormalSpec _ "," _ parameterMethodName _ ":"_..getObjectScriptType(parameter.type, parameter.in)
                    
                    Set code = $Char(9) _ "Do:$Data("_parameterMethodName_") ..setParameter("""_parameter.name_""","""_parameter.in_""","""_parameter.type_""","_parameterMethodName_")"
                    Do mDef.Implementation.WriteLine(code)

                    Set:parameter.description'="" mDef.Description =  mDef.Description  _"<br/>" _ $$$NL _ parameterMethodName _ ": " _ $Replace(parameter.description, $$$NL, "<br/>" _ $$$NL ) _ " (required : "_$Select(parameter.required:"true",1:"false") _ ")"
                
                }
                Set keyParam = ""
            }
            ;w !,mDef.FormalSpec,!
            Set mDef.Description = mDef.Description  _"<br/>" _ $$$NL _ ..getResponseDoc(serviceDefinition.responses)

            Set code = $Char(9) _ "$$$TOE(sc, ..prepare())"
            Do mDef.Implementation.WriteLine(code)

            Set upperMethod = $zcvt(method, "U")
            Set code = $Char(9) _ "$$$TOE(sc,..request.Send("""_upperMethod_""", ..addPathParam(..basePath_"""_serviceLocation _""")))"
            Do mDef.Implementation.WriteLine(code)
            
            Set code = $Char(9) _ "Return ..getResponseObject()"
            Do mDef.Implementation.WriteLine(code)

            Set mDef.ReturnType = "dc.openapi.client.Response"

            Do cDef.Methods.Insert(mDef)
        }
        Set method = ""
    }

    $$$TOE(sc, cDef.%Save())
    $$$TOE(sc, $system.OBJ.Compile(clientClass,"ck"))

    Return sc
}
*/
}
