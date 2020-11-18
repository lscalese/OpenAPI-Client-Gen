Class dc.openapi.client.Spec Extends %RegisteredObject
{

Parameter XDataName = "OpenAPI";

XData OpenAPI [ MimeType = application/json ]
{
{ "swagger":"2.0" }
}

/// Generate the client classes<br/>
/// Specify your application package in appName argument.<br/>
/// spec is the open api 2.0 specification in JSON Format<br/>
/// It could be a stream, a dynamic object or an URL.<br/>
/// ex: Set sc = ##class(dc.openapi.client.Spec).generateApp("petstore", "https://petstore.swagger.io:443/v2/swagger.json")
ClassMethod generateApp(appName As %String, spec) As %Status
{
    Set sc = $$$OK
    Try {
        If $Isobject(spec) {
            If spec.%IsA("%Stream.Object") {

                If ..isYAML(spec) { 
                    Set spec = ##class(YAML.Utils).StreamToJSON(spec, .sc)
                    If $$$ISERR(sc) $$$ThrowStatus(sc)
                
                } Else {
                    Set spec = {}.%FromJSON(spec)
                }

            }
        } Else {
            If $ZCONVERT($Extract(spec, 1, 4), "l") = "http" {
                Set spec = ..loadSpecFromUrl(spec)
            } ElseIf ##class(%File).Exists(spec) {
                Set spec = ..loadSpecFromFile(spec)
            } Else {
                $$$ThrowStatus($$$ERROR($$$GeneralError, $$$FormatText("Swagger specification not found %1.", spec)))
            }

        }
    } Catch(ex) {
        Set sc = ex.AsStatus()
        Set msg = $SYSTEM.Status.GetOneErrorText(sc)
        b
        If msg [ "Parsing err" {
            Set sc = $$$ERROR($$$GeneralError, "Currently only JSON format is supported.")
        }
    }
    
    Quit:$$$ISERR(sc) sc

    If '$Isobject(spec) || (spec.swagger '= "2.0" ) {
        Quit $$$ERROR($$$GeneralError, "Not a Swagger 2.0 file.")
    }

    s ^lsc = spec.%ToJSON()

    Return ..%CreateClientApplication(appName, spec)
}

ClassMethod loadSpecFromFile(file As %String) As %DynamicObject
{
    Set stream = ##class(%Stream.FileCharacter).%New()
    Set stream.Filename = file
    
    If ..isYAML(stream) { 
        
        Set spec = ##class(YAML.Utils).StreamToJSON(stream, .sc)
        If $$$ISERR(sc) $$$ThrowStatus(sc)

    } Else {
        w !, "no yaml"
        Set spec = {}.%FromJSON(.stream)
    }
    Return spec
}

ClassMethod loadSpecFromUrl(url As %String) As %DynamicObject
{
    Set request = ##class(%Net.HttpRequest).%New()
    Set request.Server = $Piece($Piece(url,"/",3),":",1)
    Set request.Port = $Piece($Piece(url,"/",3),":",2)
    Set protocol = $Zcvt($Piece(url,":",1),"l")
    Set request.Https = (protocol="https")
    
    If request.Https {
        Set request.SSLConfiguration = "default"
    }

    $$$TOE(sc, request.Send("GET", $Piece(url,"/",4,*)))
    
    If request.HttpResponse.StatusCode '= 200 {
        $$$ThrowStatus($$$ERROR(5001, "Http status code : " _ request.HttpResponse.StatusCode ))
    }

    Set stream = request.HttpResponse.Data

    If ..isYAML(stream) { 

        Set spec = ##class(YAML.Utils).StreamToJSON(stream, .sc)
        If $$$ISERR(sc) $$$ThrowStatus(sc)
    
    } Else {
        Set spec = {}.%FromJSON(stream)
    }

    Return spec
}

ClassMethod isYAML(stream As %Stream.Object) As %Boolean
{
    Do stream.Rewind()
    Set buffer = $zstrip(stream.Read(),"<W")
    Do stream.Rewind()
    Quit ($Extract(buffer) '= "{") && (buffer [ "swagger: ")
}

ClassMethod convertYAMLToJSON(stream As %Stream.Object, Output sc As %Status) As %Status
{
     Do ##class(YAML.Utils).StreamToJSON(stream, .sc)
}

ClassMethod %CreateClientApplication(applicationName As %String, swagger As %DynamicObject, ByRef features, Output newApplication As %Boolean) As %Status
{
    Set sc = $$$OK
   
    TStart 
    Try {
        
        Set specClass = applicationName _ ".model.spec"

        Set cDef=##class(%Dictionary.ClassDefinition).%OpenId(specClass,4,.sc)
        
        If $Isobject(cDef) {
            Do ..%RemoveXDataBlock(cDef,..#XDataName)
            Set newApplication = $$$NO
        } Else {
            Set cDef=##class(%Dictionary.ClassDefinition).%New(specClass)
            Set newApplication = $$$YES
        }

        ; $$$TOE(sc, ..generateSimpleClient()) ; must be refactor
        ; security to avoid overwrite an existing package on the server ...
        If newApplication && ##class(dc.openapi.client.Generator).packageExists(applicationName)  { 
            Set sc = $$$ERROR(5001, "Overwritting code protection.  This package already exist on the server, please choose an other appName "_applicationName)
            $$$ThrowStatus(sc)
        }

        Set cDef.Super = "%RegisteredObject"
        Set cDef.ProcedureBlock = $$$YES

        Set xData=##class(%Dictionary.XDataDefinition).%New()
        Set xData.Name=..#XDataName
        Set xData.MimeType="application/json"

        Set formatter=##class(%JSON.Formatter).%New()
        
        ; work around for an open problem with the model generation library
        ; https://github.com/grongierisc/objectscript-openapi-definition/issues/4
        Do ..translateSpec(.swagger)
        ;w !,swagger.%ToJSON()
        $$$ThrowOnError(formatter.FormatToString(swagger, .swaggerString))
        $$$ThrowOnError(xData.Data.Write(swaggerString))
        $$$ThrowOnError(cDef.XDatas.Insert(xData))
        $$$ThrowOnError(cDef.%Save())
        $$$ThrowOnError($system.OBJ.Compile(specClass,"ck-d"))
        
        Set generator = ##class(dc.openapi.client.Generator).%New(swagger, applicationName, $Get(features("compile"),$$$YES))
        Set sc = generator.generate()

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

ClassMethod %RemoveXDataBlock(cDef, blockName)
{
 	Set key = cDef.XDatas.FindObjectId(cDef.Name_"||"_blockName)
 	If (key'="") {
 		Set oid = cDef.XDatas.RemoveAt(key)
	}
}

ClassMethod translateSpec(spec) As %Status
{
    #dim iter As %Iterator.AbstractIterator = spec.paths.%GetIterator()
    #dim serviceLocation As %String
    #dim serviceDefinition As %Library.DynamicObject
    #dim method As %String

    
    While iter.%GetNext(.serviceLocation , .value ) {
        Set methodIter = value.%GetIterator()

        While methodIter.%GetNext(.method , .serviceDefinition ) {

            ; issue #15 https://github.com/lscalese/OpenAPI-Client-Gen/issues/15
            If serviceDefinition.operationId = "" {

                Set operationIdentifier = ..translateOperationId(..generateOperationId(method, serviceLocation))    
                Set serviceDefinition.operationId = operationIdentifier

            } Else {
                ; clean attempt for operationId contain /, path variable, ...
                Set serviceDefinition.operationId = $Select($Get(%zCleanSID, 1): ..cleanOperationId(serviceDefinition.operationId), 1: ..translateOperationId(serviceDefinition.operationId))
                    
            }

            #define kOpId " " _ serviceDefinition.operationId

            If '$Data(usedIdentifier($$$kOpId)) {
                Set usedIdentifier($$$kOpId) = 1
            } Else {
                Set usedIdentifier($$$kOpId) = usedIdentifier($$$kOpId) +1 
                Set serviceDefinition.operationId = serviceDefinition.operationId _ usedIdentifier($$$kOpId)
            }

            If $ISOBJECT(serviceDefinition.responses) {
                Set iterResp = serviceDefinition.responses.%GetIterator()
                While iterResp.%GetNext(.httpStatusCode , .codeObj ) {
                    Set:codeObj.schema."$ref"'="" codeObj.schema."$ref" = ..translateName(codeObj.schema."$ref")
                    Set:codeObj.schema.items."$ref"'="" codeObj.schema.items."$ref" = ..translateName(codeObj.schema.items."$ref")

                    ; manage embedded object definition
                    /*If (codeObj.schema."$ref"="") &&  (codeObj.schema.type = "object") {
                        Set nDefName = $s(codeObj.schema.title="": "Anonymous"_$Increment(cnt), 1: codeObj.schema.title)
                        Do ..transteResponseDefinition(spec, codeObj, nDefName)
                    }*/
                    ;
                }
            }

            If $ISOBJECT(serviceDefinition.parameters) {
                Set iterParams = serviceDefinition.parameters.%GetIterator()
                While iterParams.%GetNext(.paramsKey , .param ) {
                    Set:param.schema."$ref"'="" param.schema."$ref" = ..translateName(param.schema."$ref")
                    Set:param.schema.items."$ref"'="" param.schema.items."$ref" = ..translateName(param.schema.items."$ref")
                }
            }
            
        }
    }

    ;definitions

    
    Set newDef = {}, defKey = ""
    
    Set iter = spec.definitions.%GetIterator()

    While iter.%GetNext(.defKey , .def ) {
        ;w !,defKey," ", $Isobject(spec.definitions.%Get(defKey))
        
        If '$Isobject(spec.definitions.%Get(defKey)) {
            Do spec.definitions.%Remove(defKey)
            Continue
        }

        Set copyDef = {}.%FromJSON(def.%ToJSON())
        Do spec.definitions.%Remove(defKey)

        If $ISOBJECT(copyDef.properties) {
            Set iterProp = copyDef.properties.%GetIterator()

            While iterProp.%GetNext(.propKey , .propDef ) {
                Set:propDef."$ref"'="" propDef."$ref" = ..translateName(propDef."$ref")
                Set:propDef.items."$ref"'="" propDef.items."$ref" = ..translateName(propDef.items."$ref")
            }
        }

        Set newDefKey = ..translateName(defKey)
        Do newDef.%Set(..translateName(defKey), copyDef)
    }

    Set spec.definitions = newDef

    Return $$$OK
}

ClassMethod translateName(name As %String) As %IO.StringStream
{
    Return $Translate(name, "_", "")
}

ClassMethod translateOperationId(name As %String) As %IO.StringStream
{
    Return $Translate(name, "_/{}-.", "")
}

ClassMethod generateOperationId(method As %String, path As %String) As %String
{
    Set list = $LFS(path, "/"), ptr = 0, id = ""
    
    While $ListNext(list, ptr, item) {
        Set:$Extract(item, 1)'="{" id = id _ item  ; exclude path parameter
    }
    
    Return method_id
}

ClassMethod cleanOperationId(originalId As %String) As %String
{
   
    Set m=##class(%Regex.Matcher).%New("\{.*?\}", originalId)
    Set id = m.ReplaceAll("")
    Set list = $LFS(id , "/"), ptr = 0, id = ""
    While $ListNext(list, ptr, item) {
        
        Set $Extract(item,1) = $Zcvt($Extract(item,1), "U")
        Set id = id _ item 
        
    }
    
    Return ..translateOperationId(id)
}

}
